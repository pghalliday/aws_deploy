class Formatron
  module CloudFormation
    # Generates scripts for setting up instances with CloudFormation init
    # rubocop:disable Metrics/ModuleLength
    module Scripts
      def self.linux_common(sub_domain:, hosted_zone_name:)
        # rubocop:disable Metrics/LineLength
        <<-EOH.gsub(/^ {10}/, '')
          #/bin/bash -v
          set -e
          SHORTNAME=#{sub_domain}
          PUBLIC_DNS=${SHORTNAME}.#{hosted_zone_name}
          PRIVATE_IPV4=`(curl http://169.254.169.254/latest/meta-data/local-ipv4)`
          hostname $SHORTNAME
          echo $PUBLIC_DNS | tee /etc/hostname
          echo "$PRIVATE_IPV4 $PUBLIC_DNS $SHORTNAME" >> /etc/hosts
        EOH
        # rubocop:enable Metrics/LineLength
      end

      def self.windows_common(sub_domain:, hosted_zone_name:)
        # rubocop:disable Metrics/LineLength
        <<-EOH.gsub(/^ {10}/, '')
          wmic computersystem where name="%COMPUTERNAME%" call rename name="#{sub_domain}"
          REG ADD HKLM\\SYSTEM\\CurrentControlSet\\services\\Tcpip\\Parameters /v Domain /t REG_SZ /d #{hosted_zone_name} /f
          shutdown.exe /r /t 00
        EOH
        # rubocop:enable Metrics/LineLength
      end

      # rubocop:disable Metrics/MethodLength
      def self.windows_administrator(name:, password:)
        # rubocop:disable Metrics/LineLength
        <<-EOH.gsub(/^ {10}/, '')
          $newAdminName = '#{name}'
          $adminPassword = '#{password}'

          # disable password policy
          secedit /export /cfg c:\\secpol.cfg
          (gc C:\\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\\secpol.cfg
          secedit /configure /db c:\\windows\\security\\local.sdb /cfg c:\\secpol.cfg /areas SECURITYPOLICY
          rm -force c:\\secpol.cfg -confirm:$false

          # find the local administrator user
          $computerName = $env:COMPUTERNAME
          $computer = [ADSI] "WinNT://$computerName,Computer"
          foreach ( $childObject in $computer.Children ) {
            # Skip objects that are not users.
            if ( $childObject.Class -ne "User" ) {
              continue
            }
            $type = "System.Security.Principal.SecurityIdentifier"
            $childObjectSID = new-object $type($childObject.objectSid[0],0)
            if ( $childObjectSID.Value.EndsWith("-500") ) {
              $adminName = $childObject.Name[0]

              # set the new password
              $adminUser = [ADSI] "WinNT://$computerName/$adminName,User"
              $adminUser.SetPassword($adminPassword)

              # set the new name
              $user = Get-WMIObject Win32_UserAccount -Filter "Name='$adminName'"
              $result = $user.Rename($newAdminName)

              break
            }
          }
        EOH
        # rubocop:enable Metrics/LineLength
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def self.windows_signal(wait_condition_handle:)
        {
          'Fn::Join' => [
            '', [
              'cfn-signal.exe -e 0 ',
              {
                'Fn::Base64' => {
                  Ref: wait_condition_handle
                }
              }
            ]
          ]
        }
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      def self.nat(cidr:)
        # rubocop:disable Metrics/LineLength
        <<-EOH.gsub(/^ {10}/, '')
          #/bin/bash -v
          set -e
          if ! grep --quiet '^net.ipv4.ip_forward=1$' /etc/sysctl.conf; then
            sed -i '/^#net.ipv4.ip_forward=1$/c\\net.ipv4.ip_forward=1' /etc/sysctl.conf
            sysctl -p /etc/sysctl.conf
          fi
          iptables -t nat -A POSTROUTING -o eth0 -s #{cidr} -j MASQUERADE
          iptables-save > /etc/iptables.rules
          cat << EOF > /etc/network/if-pre-up.d/iptablesload
          #!/bin/sh
          iptables-restore < /etc/iptables.rules
          exit 0
          EOF
          chmod +x /etc/network/if-pre-up.d/iptablesload
        EOH
        # rubocop:enable Metrics/LineLength
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/ParameterLists
      def self.chef_server(
        username:,
        first_name:,
        last_name:,
        email:,
        password:,
        organization_short_name:,
        organization_full_name:,
        bucket:,
        user_pem_key:,
        organization_pem_key:,
        kms_key:,
        chef_server_version:,
        ssl_cert_key:,
        ssl_key_key:,
        cookbooks_bucket:
      )
        # rubocop:disable Metrics/LineLength
        <<-EOH.gsub(/^ {10}/, '')
          #!/bin/bash -v

          set -e

          export HOME=/root
          export PATH=$PATH:/usr/local/sbin/
          export PATH=$PATH:/usr/sbin/
          export PATH=$PATH:/sbin

          apt-get -y update
          apt-get -y install wget ntp cron git libfreetype6 libpng3 python-pip
          pip install awscli

          mkdir -p $HOME/.aws
          cat << EOF > $HOME/.aws/config
          [default]
          s3 =
              signature_version = s3v4
          region = ${REGION}
          EOF

          mkdir -p /etc/opscode/chef-server.rb.d

          cat << EOF > /etc/opscode/chef-server.rb
          Dir[File.dirname(__FILE__) + '/chef-server.rb.d/*.rb'].each do |file|
            self.instance_eval File.read(file), file
          end
          EOF

          cat << EOF > /etc/opscode/chef-server.rb.d/s3_cookbooks_bucket.rb
          bookshelf['enable'] = false
          bookshelf['external_url'] = 'https://s3-${REGION}.amazonaws.com'
          bookshelf['vip'] = 's3-${REGION}.amazonaws.com'
          bookshelf['access_key_id'] = '${ACCESS_KEY_ID}'
          bookshelf['secret_access_key'] = '${SECRET_ACCESS_KEY}'
          opscode_erchef['s3_bucket'] = '#{cookbooks_bucket}'
          EOF

          cat << EOF > /etc/opscode/chef-server.rb.d/ssl_certificate.rb
          nginx['ssl_certificate'] = '/etc/nginx/ssl/chef.crt'
          nginx['ssl_certificate_key'] = '/etc/nginx/ssl/chef.key'
          EOF

          mkdir -p /etc/nginx/ssl
          aws s3api get-object --bucket #{bucket} --key #{ssl_cert_key} /etc/nginx/ssl/chef.crt
          aws s3api get-object --bucket #{bucket} --key #{ssl_key_key} /etc/nginx/ssl/chef.key

          wget -O /tmp/chef-server-core.deb https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/chef-server-core_#{chef_server_version}_amd64.deb
          dpkg -i /tmp/chef-server-core.deb

          chef-server-ctl reconfigure >> /var/log/chef-install.log
          chef-server-ctl user-create #{username} #{first_name} #{last_name} #{email} #{password} --filename $HOME/user.pem >> /var/log/chef-install.log
          chef-server-ctl org-create #{organization_short_name} "#{organization_full_name}" --association_user #{username} --filename $HOME/organization.pem >> /var/log/chef-install.log

          chef-server-ctl install opscode-manage >> /var/log/chef-install.log
          chef-server-ctl reconfigure >> /var/log/chef-install.log
          opscode-manage-ctl reconfigure >> /var/log/chef-install.log

          chef-server-ctl install opscode-push-jobs-server >> /var/log/chef-install.log
          chef-server-ctl reconfigure >> /var/log/chef-install.log
          opscode-push-jobs-server-ctl reconfigure >> /var/log/chef-install.log

          chef-server-ctl install opscode-reporting >> /var/log/chef-install.log
          chef-server-ctl reconfigure >> /var/log/chef-install.log
          opscode-reporting-ctl reconfigure >> /var/log/chef-install.log

          aws s3api put-object --bucket #{bucket} --key #{user_pem_key} --body $HOME/user.pem --ssekms-key-id #{kms_key} --server-side-encryption aws:kms
          aws s3api put-object --bucket #{bucket} --key #{organization_pem_key} --body $HOME/organization.pem --ssekms-key-id #{kms_key} --server-side-encryption aws:kms
        EOH
        # rubocop:enable Metrics/LineLength
      end
      # rubocop:enable Metrics/ParameterLists
      # rubocop:enable Metrics/MethodLength
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
