package timestream

import (
	"encoding/json"
	"time"

	"github.com/kelseyhightower/envconfig"
	"go.k6.io/k6/lib/types"
)

type Config struct {
	DatabaseName string `json:"databaseName" envconfig:"K6_TIMESTREAM_DATABASE_NAME"`
	TableName    string `json:"tableName"    envconfig:"K6_TIMESTREAM_TABLE_NAME"`

	PushInterval types.NullDuration `json:"pushInterval,omitempty" envconfig:"K6_TIMESTREAM_PUSH_INTERVAL"`
}

func NewConfig() Config {
	c := Config{
		PushInterval: types.NewNullDuration(1*time.Second, false),
	}
	return c
}

func (c Config) apply(cfg Config) Config {
	if len(cfg.DatabaseName) > 0 {
		c.DatabaseName = cfg.DatabaseName
	}
	if len(cfg.TableName) > 0 {
		c.TableName = cfg.TableName
	}
	if cfg.PushInterval.Valid {
		c.PushInterval = cfg.PushInterval
	}
	return c
}

func parseJSON(data json.RawMessage) (Config, error) {
	conf := Config{}
	err := json.Unmarshal(data, &conf)
	return conf, err
}

// GetConsolidatedConfig combines {default config values + JSON config +
// environment vars config values}, and returns the final result.
func GetConsolidatedConfig(
	jsonRawConf json.RawMessage) (Config, error) {
	result := NewConfig()
	if jsonRawConf != nil {
		jsonConf, err := parseJSON(jsonRawConf)
		if err != nil {
			return result, err
		}
		result = result.apply(jsonConf)
	}

	envConfig := Config{}
	if err := envconfig.Process("", &envConfig); err != nil {
		return result, err
	}
	result = result.apply(envConfig)
	return result, nil
}
