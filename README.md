# xk6-output-timestream

Output [k6](https://k6.io/) results to [AWS Timestream](https://aws.amazon.com/timestream/) so that you can run a performant, low-cost load test.

## Why?

If you're here you've probably chosen to use k6 already and you're probably interested in using an AWS serverless service. These give you the benefits of:

- Performance at scale
- Low cost
- Great Developer experience

For more information see [the alternatives](docs/Alternatives.md)

## Usage

This output is written as an extension to K6 using [xk6 extensions](https://github.com/grafana/xk6) - this is **experimental**.

You can use this extension by either:

- Taking the k6 executable from [the latest release](https://github.com/leonyork/xk6-output-timestream/releases) and following the [instructions on running k6](https://k6.io/docs/get-started/running-k6/).
- Using the Docker image from [the latest release](https://github.com/leonyork/xk6-output-timestream/releases) and following the [instructions on running k6](https://k6.io/docs/get-started/running-k6/).
- Building this extension into K6 - see [the custom build instructions](https://github.com/grafana/xk6#custom-builds).

### Configuration

For all configuration specific to this extension see the `Config struct` in [config.go](config.go).

The key bits of config you'll need to setup are the following environment variables

```sh
K6_TIMESTREAM_DATABASE_NAME
K6_TIMESTREAM_TABLE_NAME
```

You'll also need to setup your AWS credentials - see [the guide on how to do this](https://docs.aws.amazon.com/sdk-for-go/v1/developer-guide/configuring-sdk.html#specifying-credentials).

### Tags

The dimensions (see [timestream concepts](https://docs.aws.amazon.com/timestream/latest/developerguide/concepts.html)) are taken from any K6 tags that have non-empty values.

If you do not have any tags setup you will see the error `At least one dimension is required for a record.` logged from timestream. More information can be found in [the K6 documentation](https://k6.io/docs/using-k6/tags-and-groups/) or an example of setting up tags can be found in the [integration test script](test/test.js).

### Grafana Dashboard

An [example dashboard](grafana/dashboards/loadtest/loadtest.json) is provided. You can use this dashboard by running `make grafana-build grafana-run`.

## Development

I use [VSCode](https://code.visualstudio.com/) for development so this will be the best supported editor. However, you should be able to use other IDEs. If you are using another IDE:

1. The [Dockerfile](Dockerfile) `ci` target shows all the tools you need for a dev environment (e.g. For linting).
2. There are [suggested tools](.devcontainer/tools.default.sh) you can also use.

### VSCode

The preferred way to develop using VSCode is to use the [dev container feature](https://code.visualstudio.com/learn/develop-cloud/containers). This will mean you have all the tools required and suggested for development.

If you do want to use different tools (e.g. you don't like the shell setup), create `.devcontainer/tools.override.sh` and base it off [.devcontainer/tools.default.sh](.devcontainer/tools.default.sh).

If you don't want to use dev containers, you'll need to make sure you install the tools from the [Dockerfile](Dockerfile) and the packages in [suggested tools](.devcontainer/tools.default.sh) that are needed for the VSCode extensions.

### Where to start for development

[output.go](output.go) contains the logic for converting from K6 metric samples to AWS Timestream records and then saving those records.

There are targets for different development tasks in [the Makefile](Makefile).

### Architecture

Metric samples are passed from each of the K6 VUs to `metricSamplesHandler`. This converts them to the format that the Timestream SDK expects and holds on to them until it has 100 records to save ([the max batch size for Timestream](https://docs.aws.amazon.com/timestream/latest/developerguide/API_WriteRecords.html)). It will then save these asyncronously by kicking off a new go-routine to perform the save.

The channel for receiving metric samples is closed at the end of the test and the left-over records are saved.

```mermaid
  graph TD;

    K6-VU1.AddMetricSamples--metric samples-->metricSamplesHandler
    K6-VU2.AddMetricSamples--metric samples-->metricSamplesHandler
    K6-VUN.AddMetricSamples--metric samples-->metricSamplesHandler

    metricSamplesHandler--have 100 samples?-->writeRecordsAsync
    metricSamplesHandler--shutting down?-->writeRecordsAsync

    writeRecordsAsync--new go routine-->writeRecords
```

### Testing

#### Integration

The integration tests work by creating a Timestream database and table, running a load test (with a built in test script) and then checking the results.

```mermaid
  graph LR;
    Client--deploy-->Timestream;
    Client--build-->k6;
    Client--run-->k6;
    k6--write-->Timestream;
    Client--build-->Tests;
    Client--run-->Tests;
    Tests--query-->Timestream;
    Client--destroy-->Timestream;
```

To run the integration tests you'll need to setup AWS credentials - see [the guide on how to do this](https://docs.aws.amazon.com/sdk-for-go/v1/developer-guide/configuring-sdk.html#specifying-credentials).

To deploy the Timestream database run `make deploy-infra`.

To run the tests (build, run and query steps above) run `make test-integration`. Note that you will need to build the k6 image first with `make build-image`.

To destroy the Timestream database run `make destroy-infra`.
