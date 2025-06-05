# Alternatives

What alternatives exist? First of all let's look at why k6 + AWS Timestream
could be a good solution.

## Why k6

There's a good (although written by k6!) comparison of k6 against other load
testing tools [on the k6 blog](https://k6.io/blog/k6-vs-jmeter/).

The three key points for me are:

- It's performant. As load tests get bigger they require more computing
  resources. This is expensive to orchestrate, costly, and environmentally
  unfriendly.
- I can use existing Javascript libraries. There's a broad ecosystem of
  Javascript libraries and they allow us to reproduce browser behaviour
  accurately - for big tests they're typically end 2 end acting as browsers
  would do.
- It's supported by Grafana.

## Why AWS Timestream

A lot of businesses use AWS heavily. For good reason: it provides good tooling,
it's well understood and supported, and allows huge scaling.

Whilst [Timestream](https://aws.amazon.com/timestream/) is not as mature as
other AWS products (e.g. [DynamoDB](https://aws.amazon.com/dynamodb/))
Timestream is dedicated to storing
[Timeseries data](https://en.wikipedia.org/wiki/Time_series_database). This
means the burden of spinning up and maintaining the huge, but short lived
infrastructure required for load testing is passed to AWS - and to a service
designed to gather metrics from large numbers of users (or virtual users).

## Why not

Consider alternative solutions if:

- You have support to push to
  [another k6 output](https://k6.io/docs/results-output/real-time/).
- You have an existing load testing solution.
- You have teams that prefer to use another language or a UI.

## k6 Alternatives

### Load Test Frameworks

#### Artillery

[Artillery](https://www.artillery.io/) has many of the same benefits as k6, and
I do particularly like:

- [Support for running on lambda](https://www.artillery.io/docs/guides/guides/distributed-load-tests-on-aws-lambda).
  However it's currently not possible to add plugins when running on Lambda.

#### Locust

[Locust](https://locust.io/) looks to be a great solution for teams comfortable
with Python or where there are Python libraries useful for a load test. It comes
with a UI and is quite easy to
[get started](https://docs.locust.io/en/stable/running-distributed.html) running
distributed tests - including
[an open source Terraform module](https://github.com/marcosborges/terraform-aws-loadtest-distribuited).

#### Jmeter

[Jmeter](https://jmeter.apache.org/) has a large number of performance testing
experts who are comfortable with its use. It was
[first released in 1998](https://en.wikipedia.org/wiki/Apache_JMeter#Releases)
so is battle-hardened and well understood. Since scripts are generally built
using a UI, it can be more suited to teams who do not necessarily write code.

### Datastores

#### InfluxDB

[InfluxDB](https://github.com/influxdata/influxdb) has solutions that go from
running it yourself, to running it as
[a pay-as-you-go serverless solution](https://www.influxdata.com/influxdb-pricing/).
It has multiple integrations and allows you to run SQL against your results.

#### TimescaleDB

[TimescaleDB](https://www.timescale.com) looks to be very performant, cost
effective and easy-to-use but does not currently have a serverless solution.
They published some
[interesting results in Dec 2020](https://www.timescale.com/blog/timescaledb-vs-amazon-timestream-6000x-higher-inserts-175x-faster-queries-220x-cheaper/)
showing much better performance results that suggests it would be a better
choice for larger scale tests.

## Summary

With Javascript and AWS being so popular, using k6 and Timestream should be a
great starting point for many teams.
