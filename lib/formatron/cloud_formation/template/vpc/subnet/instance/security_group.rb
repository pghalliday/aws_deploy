require 'formatron/cloud_formation/resources/ec2'

class Formatron
  module CloudFormation
    class Template
      class VPC
        class Subnet
          class Instance
            # generates CloudFormation security group resource
            class SecurityGroup
              SECURITY_GROUP_PREFIX = 'securityGroup'

              # rubocop:disable Metrics/MethodLength
              def initialize(security_group:)
                @security_group = security_group
                @instance = @security_group.dsl_parent
                @key = @instance.dsl_key
                @subnet = @instance.dsl_parent
                @vpc = @subnet.dsl_parent
                @vpc_guid = @vpc.guid
                @cidr = @vpc.cidr
                @guid = @instance.guid
                @security_group_id = "#{SECURITY_GROUP_PREFIX}#{@guid}"
                @vpc_id = "#{VPC::PREFIX}#{@vpc_guid}"
                @open_tcp_ports = @security_group.open_tcp_port
                @open_udp_ports = @security_group.open_udp_port
              end
              # rubocop:enable Metrics/MethodLength

              # rubocop:disable Metrics/MethodLength
              def merge(resources:)
                resources[@security_group_id] = Resources::EC2.security_group(
                  group_description: "#{@key} security group",
                  vpc: @vpc_id,
                  egress: _base_egress_rules,
                  ingress: _base_ingress_rules.concat(
                    @open_tcp_ports.collect do |port|
                      {
                        cidr: '0.0.0.0/0',
                        protocol: 'tcp',
                        from_port: port,
                        to_port: port
                      }
                    end
                  ).concat(
                    @open_udp_ports.collect do |port|
                      {
                        cidr: '0.0.0.0/0',
                        protocol: 'udp',
                        from_port: port,
                        to_port: port
                      }
                    end
                  )
                )
              end
              # rubocop:enable Metrics/MethodLength

              # rubocop:disable Metrics/MethodLength
              def _base_egress_rules
                [{
                  cidr: '0.0.0.0/0',
                  protocol: 'tcp',
                  from_port: '0',
                  to_port: '65535'
                }, {
                  cidr: '0.0.0.0/0',
                  protocol: 'udp',
                  from_port: '0',
                  to_port: '65535'
                }, {
                  cidr: '0.0.0.0/0',
                  protocol: 'icmp',
                  from_port: '-1',
                  to_port: '-1'
                }]
              end
              # rubocop:enable Metrics/MethodLength

              # rubocop:disable Metrics/MethodLength
              def _base_ingress_rules
                [{
                  cidr: @cidr,
                  protocol: 'tcp',
                  from_port: '0',
                  to_port: '65535'
                }, {
                  cidr: @cidr,
                  protocol: 'udp',
                  from_port: '0',
                  to_port: '65535'
                }, {
                  cidr: @cidr,
                  protocol: 'icmp',
                  from_port: '-1',
                  to_port: '-1'
                }]
              end
              # rubocop:enable Metrics/MethodLength

              private(
                :_base_egress_rules,
                :_base_ingress_rules
              )
            end
          end
        end
      end
    end
  end
end
