# xk6-output-timestream

Output [k6](https://k6.io/) results to [AWS Timestream](https://aws.amazon.com/timestream/) so that you can run a performant, low-cost load test.

## Why?

If you're here you've probably chosen to use k6 already and you're probably interested in using an AWS serverless service. These give you the benefits of:

- Performance at scale
- Low cost
- Great Developer experience

For more information see [the alternatives](docs/Alternatives.md)

## Usage

This output is written as an extension to K6 using [xk6 extensions](https://github.com/grafana/xk6) - this is **experimental**. You'll need to build this into K6 - see [the custom build instructions](https://github.com/grafana/xk6#custom-builds).

## Development
