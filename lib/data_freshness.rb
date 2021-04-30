require 'datadog/statsd'
require 'aws-sdk-s3'
require_relative './config'

# Records timeliness of data-processing tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    artist_career_stage: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistCareerStage/' },
    artist_gene_value: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistGeneValue/' },
    artist_related_genes: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistRelatedGenes/' },
    artist_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistSimilarity/' },
    artist_trending: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistTrending/' },
    artwork_gene_value: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkGeneValue/' },
    artwork_iconicity: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkIconicity/' },
    artwork_merchandisability: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkMerchandisability/' },
    cf_artwork_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/CFArtworkSimilarity/' },
    contemporary_artist_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/ContemporaryArtistSimilarity/' },
    gene_partitioned_artist_trending: { bucket: 'artsy-cinder-production', prefix: 'builds/GenePartitionedArtistTrending/' },
    gene_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/GeneSimilarity/' },
    sitemaps: { bucket: 'artsy-sitemaps', prefix: 'sitemap-artist-series' }, # This is because in hue artist series is the last task to run in the chained sitemap tasks
    tag_count: { bucket: 'artsy-cinder-production', prefix: 'builds/TagCount/' },
    user_artwork_suggestions: { bucket: 'artsy-cinder-production', prefix: 'builds/UserArtworkSuggestions/' },
    user_genome: { bucket: 'artsy-cinder-production', prefix: 'builds/UserGenome/' },
    user_price_preference: { bucket: 'artsy-cinder-production', prefix: 'builds/UserPricePreference/' },
  }

  def self.record_metrics
    new.record_metrics
  end

  def record_metrics
    S3_LOCATIONS.each do |key, s3|
      last_modified = s3_client.list_objects(bucket:s3[:bucket], prefix:s3[:prefix]).flat_map do |response|
        response.contents.map(&:last_modified)
      end.max
      next unless last_modified
      age =  Time.now - last_modified
      $stderr.puts "Recording data_freshness for #{key} as #{last_modified} with an age of #{age}"
      statsd.gauge "data_freshness.#{key}", age # seconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: Config.values[:aws_access_key_id],
      secret_access_key: Config.values[:aws_secret_access_key]
    )
  end
end
