/**
 * K6 Extension that writes results to AWS Timestream.
 * Based on some of the outputs from the official K6
 * repo. See
 * https://github.com/grafana/k6/tree/master/output
 */

package timestream

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite/types"

	"github.com/aws/aws-sdk-go-v2/service/timestreamwrite"

	"github.com/aws/aws-sdk-go-v2/config"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/sirupsen/logrus"

	"go.k6.io/k6/metrics"
	"go.k6.io/k6/output"
)

func init() {
	output.RegisterExtension("timestream", New)
}

type TimestreamWriteClient interface {
	WriteRecords(
		ctx context.Context,
		params *timestreamwrite.WriteRecordsInput,
		optFns ...func(*timestreamwrite.Options),
	) (*timestreamwrite.WriteRecordsOutput, error)
}

type Output struct {
	client TimestreamWriteClient
	config *Config
	logger logrus.FieldLogger

	metricSampleContainerQueue chan *metrics.SampleContainer
	doneWriting                chan bool
}

func New(params output.Params) (output.Output, error) {
	extensionConfig, err := GetConsolidatedConfig(params.JSONConfig)
	if err != nil {
		return nil, err
	}

	awsConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		return nil, err
	}
	if extensionConfig.Region != "" {
		awsConfig.Region = extensionConfig.Region
	}

	client := timestreamwrite.NewFromConfig(awsConfig)

	return &Output{
		client: client,
		config: &extensionConfig,
		logger: params.Logger.WithField("component", "timestream"),
	}, nil
}

func (o *Output) Description() string {
	return fmt.Sprintf(
		"Timestream (%s:%s)",
		o.config.DatabaseName,
		o.config.TableName,
	)
}

func (o *Output) Start() error {
	o.logger.Debug("Starting...")
	o.metricSampleContainerQueue = make(chan *metrics.SampleContainer)
	o.doneWriting = make(chan bool)
	go o.metricSamplesHandler()
	o.logger.Debug("Started!")
	return nil
}

func (o *Output) Stop() error {
	o.logger.Debug("Stopping...")
	close(o.metricSampleContainerQueue)
	o.logger.Debug("Closed MetricSampleContainerQueue")
	<-o.doneWriting
	o.logger.Debug("Stopped!")
	return nil
}

func (o *Output) AddMetricSamples(samples []metrics.SampleContainer) {
	for _, sampleContainer := range samples {
		sampleContainer := sampleContainer
		o.metricSampleContainerQueue <- &sampleContainer
	}
}

/**
 * Pulls together all the metrics in one place in the correct format for timestream
 * so that it can write the metrics when it reaches the TIMESTREAM_MAX_BATCH_SIZE
 */
func (o *Output) metricSamplesHandler() {
	// See https://docs.aws.amazon.com/timestream/latest/developerguide/API_WriteRecords.html
	TIMESTREAM_MAX_BATCH_SIZE := 100
	var timestreamRecordsToSave []types.Record
	var wg sync.WaitGroup
	start := time.Now()
	totalWritten := 0
	for metricSampleContainer := range o.metricSampleContainerQueue {
		timestreamRecordsForContainer := o.createRecords((*metricSampleContainer).GetSamples())
		timestreamRecordsToSave = append(timestreamRecordsToSave, timestreamRecordsForContainer...)

		if len(timestreamRecordsToSave) > TIMESTREAM_MAX_BATCH_SIZE {
			o.writeRecordsAsync(timestreamRecordsToSave[:TIMESTREAM_MAX_BATCH_SIZE], &wg, &start)
			timestreamRecordsToSave = timestreamRecordsToSave[TIMESTREAM_MAX_BATCH_SIZE:]
			totalWritten += TIMESTREAM_MAX_BATCH_SIZE
		}
	}

	if len(timestreamRecordsToSave) > 0 {
		o.writeRecordsAsync(timestreamRecordsToSave, &wg, &start)
		totalWritten += len(timestreamRecordsToSave)
	}

	o.logger.Debugf("Wrote %d records to timestream", totalWritten)

	wg.Wait()
	o.logger.Debug("Metric samples handler done")
	o.doneWriting <- true
}

/**
 * Mapping from K6 metrics to AWS Timstream records
 */
func (o *Output) createRecords(samples []metrics.Sample) []types.Record {
	records := make([]types.Record, 0, len(samples))
	for _, sample := range samples {
		var dimensions []types.Dimension

		for tagKey, tagValue := range sample.Tags.CloneTags() {
			if len(strings.TrimSpace(tagValue)) == 0 {
				o.logger.Debug(fmt.Sprintf("Ignoring tag %s", tagKey))
				continue
			}

			dimensions = append(dimensions, types.Dimension{
				Name:  aws.String(tagKey),
				Value: aws.String(tagValue),
			})
		}

		records = append(records, types.Record{
			Dimensions:       dimensions,
			MeasureName:      aws.String(sample.Metric.Name),
			MeasureValue:     aws.String(fmt.Sprintf("%.6f", sample.Value)),
			MeasureValueType: "DOUBLE",
			Time: aws.String(
				fmt.Sprintf("%d", sample.GetTime().UnixNano()),
			),
			TimeUnit: "NANOSECONDS",
		})
	}
	return records
}

/**
 * We perform the save to the database in a separate
 * thread as the network call is orders of magnitude
 * slower than running on the CPU and can be done in
 * parallel. This ultimately means we don't end up
 * waiting for a long time after the tests have
 * finished for data to be written to the database
 */
func (o *Output) writeRecordsAsync(
	records []types.Record,
	waitGroup *sync.WaitGroup,
	startTime *time.Time,
) {
	waitGroup.Add(1)
	go func(recordsToSave *[]types.Record) {
		defer waitGroup.Done()

		logger := o.logger.
			WithField("count", len(*recordsToSave)).
			WithField("records_address", &recordsToSave)

		logger.WithField("t", time.Since(*startTime)).
			Debug("Starting write")

		startWriteTime := time.Now()
		countSaved, err := o.writeRecords(recordsToSave)

		if err != nil {
			logger.
				WithField("t", time.Since(*startTime)).
				WithField("duration", time.Since(startWriteTime)).
				WithError(err).
				Error("Failed to write")
			return
		}
		logger.
			WithField("t", time.Since(*startTime)).
			WithField("duration", time.Since(startWriteTime)).
			WithField("count_saved", countSaved).
			Debug("Wrote metrics")
	}(&records)
}

func (o *Output) writeRecords(records *[]types.Record) (int32, error) {
	writeRecordsInput := &timestreamwrite.WriteRecordsInput{
		DatabaseName: aws.String(o.config.DatabaseName),
		TableName:    aws.String(o.config.TableName),
		Records:      *records,
	}

	response, err := o.client.WriteRecords(context.TODO(), writeRecordsInput)

	if err != nil {
		return 0, err
	}

	return response.RecordsIngested.Total, nil
}
