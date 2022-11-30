package timestream

import (
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestNewConfig(t *testing.T) {
	t.Parallel()
	config := NewConfig()

	t.Run("The Region is empty", func(t *testing.T) {
		t.Parallel()
		assert.Equal(t, "", config.Region)
	})

	t.Run("The DatabaseName is empty", func(t *testing.T) {
		t.Parallel()
		assert.Equal(t, "", config.DatabaseName)
	})

	t.Run("The TableName is empty", func(t *testing.T) {
		t.Parallel()
		assert.Equal(t, "", config.TableName)
	})

	t.Run("The PushInterval is 1s", func(t *testing.T) {
		t.Parallel()
		assert.Equal(
			t,
			time.Duration(1)*time.Second,
			time.Duration(config.PushInterval.Duration),
		)
	})
}

func TestGetConsolidatedConfig(t *testing.T) {
	os.Clearenv()

	t.Run("Defaults applied correctly", func(t *testing.T) {
		config, err := GetConsolidatedConfig([]byte("{}"))
		assert.NoError(t, err)
		assert.Equal(t, "", config.Region)
		assert.Equal(t, "", config.DatabaseName)
		assert.Equal(t, "", config.TableName)
		assert.Equal(
			t,
			time.Duration(1)*time.Second,
			time.Duration(config.PushInterval.Duration),
		)
	})

	testJson := []byte(
		`{"region": "us-east-1", "databaseName": "testDbJson", "tableName": "testTableJson", "pushInterval": "30s"}`,
	)

	t.Run("JSON is applied correctly", func(t *testing.T) {
		config, err := GetConsolidatedConfig(testJson)
		assert.NoError(t, err)
		assert.Equal(t, "us-east-1", config.Region)
		assert.Equal(t, "testDbJson", config.DatabaseName)
		assert.Equal(t, "testTableJson", config.TableName)
		assert.Equal(
			t,
			time.Duration(30)*time.Second,
			time.Duration(config.PushInterval.Duration),
		)
	})

	os.Setenv("K6_TIMESTREAM_REGION", "eu-west-1")
	os.Setenv("K6_TIMESTREAM_DATABASE_NAME", "testDbEnv")
	os.Setenv("K6_TIMESTREAM_TABLE_NAME", "testTableEnv")
	os.Setenv("K6_TIMESTREAM_PUSH_INTERVAL", "1h")

	t.Run("Env variables applied correctly", func(t *testing.T) {
		config, err := GetConsolidatedConfig([]byte("{}"))
		assert.NoError(t, err)
		assert.Equal(t, "eu-west-1", config.Region)
		assert.Equal(t, "testDbEnv", config.DatabaseName)
		assert.Equal(t, "testTableEnv", config.TableName)
		assert.Equal(
			t,
			time.Duration(1)*time.Hour,
			time.Duration(config.PushInterval.Duration),
		)
	})

	t.Run(
		"Env variables applied correctly over json variables",
		func(t *testing.T) {
			config, err := GetConsolidatedConfig(testJson)
			assert.NoError(t, err)
			assert.Equal(t, "eu-west-1", config.Region)
			assert.Equal(t, "testDbEnv", config.DatabaseName)
			assert.Equal(t, "testTableEnv", config.TableName)
			assert.Equal(
				t,
				time.Duration(1)*time.Hour,
				time.Duration(config.PushInterval.Duration),
			)
		},
	)
}
