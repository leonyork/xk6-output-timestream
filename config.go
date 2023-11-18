package timestream

import (
	"encoding/json"
	"fmt"

	"github.com/kelseyhightower/envconfig"
)

type Config struct {
	Region       string `envconfig:"K6_TIMESTREAM_REGION"        json:"region"`
	DatabaseName string `envconfig:"K6_TIMESTREAM_DATABASE_NAME" json:"databaseName"`
	TableName    string `envconfig:"K6_TIMESTREAM_TABLE_NAME"    json:"tableName"`
}

func NewConfig() Config {
	c := Config{}

	return c
}

func (c Config) apply(cfg Config) Config {
	if len(cfg.Region) > 0 {
		c.Region = cfg.Region
	}

	if len(cfg.DatabaseName) > 0 {
		c.DatabaseName = cfg.DatabaseName
	}

	if len(cfg.TableName) > 0 {
		c.TableName = cfg.TableName
	}

	return c
}

func parseJSON(data json.RawMessage) (Config, error) {
	conf := Config{}
	if err := json.Unmarshal(data, &conf); err != nil {
		return conf, fmt.Errorf("unable to parse json: %w", err)
	}

	return conf, nil
}

// GetConsolidatedConfig combines {default config values + JSON config +
// environment vars config values}, and returns the final result.
func GetConsolidatedConfig(
	jsonRawConf json.RawMessage,
) (Config, error) {
	result := NewConfig()

	if jsonRawConf != nil {
		jsonConf, err := parseJSON(jsonRawConf)
		if err != nil {
			return result, fmt.Errorf("unable to parse json config: %w", err)
		}

		result = result.apply(jsonConf)
	}

	envConfig := Config{}
	if err := envconfig.Process("", &envConfig); err != nil {
		return result, fmt.Errorf("unable to parse env config: %w", err)
	}

	result = result.apply(envConfig)

	return result, nil
}
