# Alternatives

What alternatives exists the solution in this repo? First of all let's look at why K6 + AWS Timestream could be a good solution.

## Why k6

There's a good, but maybe biased, comparison of k6 against other load testing tools [here](https://k6.io/blog/k6-vs-jmeter/).

The three key points for me are:

- It's performant. As load tests get bigger they require more computing resources. This is expensive to orchestrate, costly, and enviromentally unfriendly.
- I can use existing Javascript libraries. There's a broad ecosystem of Javascript libraries and they allow us to reproduce broswer behaviour accurately - for big tests they're typically end 2 end acting as browsers would do.
- It's supported by Grafana.

## Why AWS Timestream

A lot of buninesses are tied into AWS. For good reason: it provides good tooling, it's well understood and supported, and allows huge scaling.

Whilst [Timestream](https://aws.amazon.com/timestream/) is not as mature as other products (e.g. [DynamoDB](https://aws.amazon.com/dynamodb/)), Timestream is also Serverless but dedicated to storing [Timeseries data](https://en.wikipedia.org/wiki/Time_series_database). This means the burden of spinning up and maintaining the huge, but short lived infrastructure required for load testing is passed to AWS - and to a service designed to gather metrics from large numbers of users (or virtual users).

## Why not

Consider alternative solutions if:

- You have support to push to [another K6 output](https://k6.io/docs/results-output/real-time/).
- You have an existing load testing solution.

## K6 Alternatives

### Load Test Frameworks

#### Artillery

[Artillery](https://www.artillery.io/) has many of the same benefits as K6, however:

- Looks to be mostly [a single person supporting the project](https://github.com/artilleryio/artillery/commits/master)

I do particularly like:

- [Support for running on lambda](https://www.artillery.io/docs/guides/guides/distributed-load-tests-on-aws-lambda). However it's currently not possible to add plugins.

#### Locust

TODO

#### Jmeter

TODO

### Datastores

#### InfluxDB

TODO

#### DynamoDB

TODO
