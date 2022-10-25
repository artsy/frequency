# Frequency

Runs as a periodic cron to record recent cycle time metrics to statsd.

## Development

    ./bin/setup

To run tests:

    bundle exec rspec

To run tasks locally (e.g.):

    foreman run bundle exec rake record:data_freshness

## Testing Datadog

Some of the tasks in this repo send metrics to Datadog via [dogstatsd](https://github.com/DataDog/dogstatsd-ruby). If you are adding a task that does something similar, you might want to test sending metric from your local to Datadog. You can do that by:

- Spin up a local dd-agent using Hokusai:

    ```
    hokusai dev start
    ```

- Run the task locally, for example:

    ```
    foreman run bundle exec rake record:data_freshness
    ```

- You can also run the task via Hokusai:

    ```
    hokusai dev run "bundle exec rake record:data_freshness"
    ```

- Confirm it works by locating the metric on [Datadog Metrics Explorer UI](https://app.datadoghq.com/metric/explorer). There's a lag of a few minutes.
