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

### Configuration

For all configuration specific to this extension see the `Config struct` in [config.go](config.go).

The key bits of config you'll need to setup are the following environment variables

```sh
K6_TIMESTREAM_DATABASE_NAME
K6_TIMESTREAM_TABLE_NAME
```

There is a sample command in the `test-integration` target in [the Makefile](Makefile).

You'll also need to setup your AWS credentials - see [the guide on how to do this](https://docs.aws.amazon.com/sdk-for-go/v1/developer-guide/configuring-sdk.html#specifying-credentials).

### Tags

The dimensions (see [timestream concepts](https://docs.aws.amazon.com/timestream/latest/developerguide/concepts.html)) are taken from any K6 tags that have non-empty values.

If you do not have any tags setup you will see the error `At least one dimension is required for a record.` logged from timestream. More information can be found in [the K6 documentation](https://k6.io/docs/using-k6/tags-and-groups/) or an example of setting up tags can be found in the [integration test script](test/test.js).

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
