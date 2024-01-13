package timestream

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestNewConfig(t *testing.T) {
	t.Parallel()

	config := NewConfig()

	t.Run("The Region is empty", func(t *testing.T) {
		t.Parallel()
		require.Equal(t, "", config.Region)
	})

	t.Run("The DatabaseName is empty", func(t *testing.T) {
		t.Parallel()
		require.Equal(t, "", config.DatabaseName)
	})

	t.Run("The TableName is empty", func(t *testing.T) {
		t.Parallel()
		require.Equal(t, "", config.TableName)
	})
}

func TestGetConsolidatedConfig(t *testing.T) {
	os.Clearenv()

	t.Run("Defaults applied correctly", func(t *testing.T) {
		t.Parallel()
		config, err := GetConsolidatedConfig([]byte("{}"), map[string]string{})
		require.NoError(t, err)
		require.Equal(t, "", config.Region)
		require.Equal(t, "", config.DatabaseName)
		require.Equal(t, "", config.TableName)
	})

	testJSON := []byte(
		`{"region": "us-east-1", "databaseName": "testDbJson", "tableName": "testTableJson", "pushInterval": "30s"}`,
	)

	t.Run("JSON is applied correctly", func(t *testing.T) {
		t.Parallel()
		config, err := GetConsolidatedConfig(testJSON, map[string]string{})
		require.NoError(t, err)
		require.Equal(t, "us-east-1", config.Region)
		require.Equal(t, "testDbJson", config.DatabaseName)
		require.Equal(t, "testTableJson", config.TableName)
	})

	t.Run("Env variables applied correctly", func(t *testing.T) {
		config, err := GetConsolidatedConfig([]byte("{}"), map[string]string{
			"K6_TIMESTREAM_REGION":        "eu-west-1",
			"K6_TIMESTREAM_DATABASE_NAME": "testDbEnv",
			"K6_TIMESTREAM_TABLE_NAME":    "testTableEnv",
			"K6_TIMESTREAM_PUSH_INTERVAL": "1h",
		})
		require.NoError(t, err)
		require.Equal(t, "eu-west-1", config.Region)
		require.Equal(t, "testDbEnv", config.DatabaseName)
		require.Equal(t, "testTableEnv", config.TableName)
	})

	t.Run(
		"Env variables applied correctly over json variables",
		func(t *testing.T) {
			config, err := GetConsolidatedConfig(testJSON, map[string]string{
				"K6_TIMESTREAM_REGION":        "eu-west-1",
				"K6_TIMESTREAM_DATABASE_NAME": "testDbEnv",
				"K6_TIMESTREAM_TABLE_NAME":    "testTableEnv",
				"K6_TIMESTREAM_PUSH_INTERVAL": "1h",
			})
			require.NoError(t, err)
			require.Equal(t, "eu-west-1", config.Region)
			require.Equal(t, "testDbEnv", config.DatabaseName)
			require.Equal(t, "testTableEnv", config.TableName)
		},
	)
}
