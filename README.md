# Frequency

Runs as a periodic cron to record recent cycle time metrics to statsd.

## Development

    ./bin/setup

To run tests:

    bundle exec rspec

To run tasks locally (e.g.):

    foreman run bundle exec rake record:data_freshness
