require_relative 'subnet/nat'
require_relative 'subnet/bastion'
require_relative 'subnet/chef_server'
require_relative 'subnet/instance'
require_relative 'subnet/acl'
require_relative '../vpc'
require 'formatron/cloud_formation/resources/ec2'

class Formatron
  module CloudFormation
    class Template
      class VPC
        # generates CloudFormation subnet resources
        class Subnet
          PREFIX = 'subnet'
          SUBNET_ROUTE_TABLE_ASSOCIATION_PREFIX = 'subnetRouteTableAssociation'

          # rubocop:disable Metrics/MethodLength
          def initialize(subnet:)
            @subnet = subnet
            @vpc = subnet.dsl_parent
            @guid = @subnet.guid
            @vpc_guid = @vpc.guid
            @subnet_id = "#{PREFIX}#{@guid}"
            @subnet_route_table_association_id =
              "#{SUBNET_ROUTE_TABLE_ASSOCIATION_PREFIX}#{@guid}"
            @vpc_id = "#{VPC::PREFIX}#{@vpc_guid}"
            @public_route_table_id =
              "#{VPC::ROUTE_TABLE_PREFIX}#{@vpc_guid}"
            @gateway = @subnet.gateway
            @availability_zone = @subnet.availability_zone
            @cidr = @subnet.cidr
            @acl = @subnet.acl
          end
          # rubocop:enable Metrics/MethodLength

          # rubocop:disable Metrics/MethodLength
          def merge(resources:, outputs:)
            {
              nat: NAT,
              bastion: Bastion,
              chef_server: ChefServer,
              instance: Instance
            }.each do |symbol, cls|
              @subnet.send(symbol).each do |_, instance|
                instance = cls.new symbol => instance
                instance.merge resources: resources, outputs: outputs
              end
            end
            _add_subnet resources, outputs
            _add_subnet_route_table_association resources
            _add_acl resources if @acl && @gateway.nil?
          end
          # rubocop:enable Metrics/MethodLength

          def _add_subnet(resources, outputs)
            resources[@subnet_id] = Resources::EC2.subnet(
              vpc: @vpc_id,
              cidr: @cidr,
              availability_zone: @availability_zone,
              map_public_ip_on_launch: @gateway.nil?
            )
            outputs[@subnet_id] = Template.output Template.ref(@subnet_id)
          end

          # rubocop:disable Metrics/MethodLength
          def _add_subnet_route_table_association(resources)
            route_table = @public_route_table_id
            puts @gateway
            unless @gateway.nil?
              gateway_guid = @vpc.dsl_parent.dsl_parent.instance(
                name: @gateway
              ).guid
              route_table = "#{NAT::ROUTE_TABLE_PREFIX}#{gateway_guid}"
            end
            resources[@subnet_route_table_association_id] =
              Resources::EC2.subnet_route_table_association(
                route_table: route_table,
                subnet: @subnet_id
              )
          end
          # rubocop:enable Metrics/MethodLength

          def _add_acl(resources)
            acl = ACL.new acl: @acl
            acl.merge resources: resources
          end

          private(
            :_add_subnet,
            :_add_subnet_route_table_association,
            :_add_acl
          )
        end
      end
    end
  end
end
