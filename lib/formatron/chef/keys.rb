require 'formatron/s3/chef_server_keys'

class Formatron
  class Chef
    # Download the Chef Server keys
    class Keys
      def initialize(aws:, bucket:, name:, target:, guid:)
        @aws = aws
        @bucket = bucket
        @name = name
        @target = target
        @guid = guid
      end

      def init
        @directory = Dir.mktmpdir 'formatron-chef-server-keys-'
        S3::ChefServerKeys.get(
          aws: @aws,
          bucket: @bucket,
          name: @name,
          target: @target,
          guid: @guid,
          directory: @directory
        )
      end

      def user_key
        S3::ChefServerKeys.user_pem_path directory: @directory
      end

      def organization_key
        S3::ChefServerKeys.organization_pem_path directory: @directory
      end

      def unlink
        FileUtils.rm_rf @directory unless @directory.nil?
      end
    end
  end
end
