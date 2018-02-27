#!/bin/bash

set -exu

source pcf-pipelines/functions/generate_cert.sh

NETWORKING_POE_SSL_CERTS_JSON="$(ruby -r yaml -r json -e 'puts JSON.dump(YAML.load(ENV["NETWORKING_POE_SSL_CERTS"]))')"

if [[ ${NETWORKING_POE_SSL_CERTS} == "" || ${NETWORKING_POE_SSL_CERTS} == "generate" || ${NETWORKING_POE_SSL_CERTS} == null ]]; then
  domains=(
    "*.${SYSTEM_DOMAIN}"
    "*.${APPS_DOMAIN}"
    "*.login.${SYSTEM_DOMAIN}"
    "*.uaa.${SYSTEM_DOMAIN}"
  )

  certificate=$(generate_cert "${domains[*]}")
  pcf_ert_ssl_cert=`echo $certificate | jq '.certificate'`
  pcf_ert_ssl_key=`echo $certificate | jq '.key'`
  NETWORKING_POE_SSL_CERTS_JSON="[
    {
      \"name\": \"Certificate 1\",
      \"certificate\": {
        \"cert_pem\": $pcf_ert_ssl_cert,
        \"private_key_pem\": $pcf_ert_ssl_key
      }
    }
  ]"
fi


if [[ -z "$SAML_SSL_CERT" ]]; then
  saml_cert_domains=(
    "*.${SYSTEM_DOMAIN}"
    "*.login.${SYSTEM_DOMAIN}"
    "*.uaa.${SYSTEM_DOMAIN}"
  )

  saml_certificates=$(generate_cert "${saml_cert_domains[*]}")
  SAML_SSL_CERT=$(echo $saml_certificates | jq --raw-output '.certificate')
  SAML_SSL_PRIVATE_KEY=$(echo $saml_certificates | jq --raw-output '.key')
fi

CREDHUB_ENCRYPTION_KEYS_JSON="$(ruby -r yaml -r json -e 'puts JSON.dump(YAML.load(ENV["CREDHUB_ENCRYPTION_KEYS"]))')"

cf_properties=$(
  jq -n \
    --arg tcp_routing "$TCP_ROUTING" \
    --arg tcp_routing_ports "$TCP_ROUTING_PORTS" \
    --arg loggregator_endpoint_port "$LOGGREGATOR_ENDPOINT_PORT" \
    --arg route_services "$ROUTE_SERVICES" \
    --arg ignore_ssl_cert "$IGNORE_SSL_CERT" \
    --arg security_acknowledgement "$SECURITY_ACKNOWLEDGEMENT" \
    --arg system_domain "$SYSTEM_DOMAIN" \
    --arg apps_domain "$APPS_DOMAIN" \
    --arg default_quota_memory_limit_in_mb "$DEFAULT_QUOTA_MEMORY_LIMIT_IN_MB" \
    --arg default_quota_max_services_count "$DEFAULT_QUOTA_MAX_SERVICES_COUNT" \
    --arg allow_app_ssh_access "$ALLOW_APP_SSH_ACCESS" \
    --arg ha_proxy_ips "$HA_PROXY_IPS" \
    --arg skip_cert_verify "$SKIP_CERT_VERIFY" \
    --arg router_static_ips "$ROUTER_STATIC_IPS" \
    --arg disable_insecure_cookies "$DISABLE_INSECURE_COOKIES" \
    --arg router_request_timeout_seconds "$ROUTER_REQUEST_TIMEOUT_IN_SEC" \
    --arg mysql_monitor_email "$MYSQL_MONITOR_EMAIL" \
    --arg tcp_router_static_ips "$TCP_ROUTER_STATIC_IPS" \
    --arg company_name "$COMPANY_NAME" \
    --arg ssh_static_ips "$SSH_STATIC_IPS" \
    --arg mysql_static_ips "$MYSQL_STATIC_IPS" \
    --arg haproxy_forward_tls "$HAPROXY_FORWARD_TLS" \
    --arg haproxy_backend_ca "$HAPROXY_BACKEND_CA" \
    --arg router_tls_ciphers "$ROUTER_TLS_CIPHERS" \
    --arg routing_tls_termination $ROUTING_TLS_TERMINATION \
    --arg routing_custom_ca_certificates "$ROUTING_CUSTOM_CA_CERTIFICATES" \
    --arg haproxy_tls_ciphers "$HAPROXY_TLS_CIPHERS" \
    --arg disable_http_proxy "$DISABLE_HTTP_PROXY" \
    --arg smtp_from "$SMTP_FROM" \
    --arg smtp_address "$SMTP_ADDRESS" \
    --arg smtp_port "$SMTP_PORT" \
    --arg smtp_user "$SMTP_USER" \
    --arg smtp_password "$SMTP_PWD" \
    --arg smtp_enable_starttls_auto "$SMTP_ENABLE_STARTTLS_AUTO" \
    --arg smtp_auth_mechanism "$SMTP_AUTH_MECHANISM" \
    --arg enable_security_event_logging "$ENABLE_SECURITY_EVENT_LOGGING" \
    --arg syslog_host "$SYSLOG_HOST" \
    --arg syslog_drain_buffer_size "$SYSLOG_DRAIN_BUFFER_SIZE" \
    --arg syslog_port "$SYSLOG_PORT" \
    --arg syslog_protocol "$SYSLOG_PROTOCOL" \
    --arg authentication_mode "$AUTHENTICATION_MODE" \
    --arg ldap_url "$LDAP_URL" \
    --arg ldap_user "$LDAP_USER" \
    --arg ldap_password "$LDAP_PWD" \
    --arg ldap_search_base "$SEARCH_BASE" \
    --arg ldap_search_filter "$SEARCH_FILTER" \
    --arg ldap_group_search_base "$GROUP_SEARCH_BASE" \
    --arg ldap_group_search_filter "$GROUP_SEARCH_FILTER" \
    --arg ldap_mail_attr_name "$MAIL_ATTR_NAME" \
    --arg ldap_first_name_attr "$FIRST_NAME_ATTR" \
    --arg ldap_last_name_attr "$LAST_NAME_ATTR" \
    --arg saml_cert_pem "$SAML_SSL_CERT" \
    --arg saml_key_pem "$SAML_SSL_PRIVATE_KEY" \
    --arg mysql_backups "$MYSQL_BACKUPS" \
    --arg mysql_backups_s3_endpoint_url "$MYSQL_BACKUPS_S3_ENDPOINT_URL" \
    --arg mysql_backups_s3_bucket_name "$MYSQL_BACKUPS_S3_BUCKET_NAME" \
    --arg mysql_backups_s3_bucket_path "$MYSQL_BACKUPS_S3_BUCKET_PATH" \
    --arg mysql_backups_s3_access_key_id "$MYSQL_BACKUPS_S3_ACCESS_KEY_ID" \
    --arg mysql_backups_s3_secret_access_key "$MYSQL_BACKUPS_S3_SECRET_ACCESS_KEY" \
    --arg mysql_backups_s3_cron_schedule "$MYSQL_BACKUPS_S3_CRON_SCHEDULE" \
    --arg mysql_backups_scp_server "$MYSQL_BACKUPS_SCP_SERVER" \
    --arg mysql_backups_scp_port "$MYSQL_BACKUPS_SCP_PORT" \
    --arg mysql_backups_scp_user "$MYSQL_BACKUPS_SCP_USER" \
    --arg mysql_backups_scp_key "$MYSQL_BACKUPS_SCP_KEY" \
    --arg mysql_backups_scp_destination "$MYSQL_BACKUPS_SCP_DESTINATION" \
    --arg mysql_backups_scp_cron_schedule "$MYSQL_BACKUPS_SCP_CRON_SCHEDULE" \
    --argjson credhub_encryption_keys "$CREDHUB_ENCRYPTION_KEYS_JSON" \
    --arg container_networking_nw_cidr "$CONTAINER_NETWORKING_NW_CIDR" \
    '
    {
      ".properties.system_blobstore": {
        "value": "internal"
      },
      ".properties.logger_endpoint_port": {
        "value": $loggregator_endpoint_port
      },
      ".properties.container_networking.enable.network_cidr": {
        "value": $container_networking_nw_cidr
      },
      ".properties.security_acknowledgement": {
        "value": $security_acknowledgement
      },
      ".push-apps-manager.company_name": {
        "value": $company_name
      },
      ".cloud_controller.system_domain": {
        "value": $system_domain
      },
      ".cloud_controller.apps_domain": {
        "value": $apps_domain
      },
      ".cloud_controller.default_quota_memory_limit_mb": {
        "value": $default_quota_memory_limit_in_mb
      },
      ".cloud_controller.default_quota_max_number_services": {
        "value": $default_quota_max_services_count
      },
      ".cloud_controller.allow_app_ssh_access": {
        "value": $allow_app_ssh_access
      },
      ".ha_proxy.static_ips": {
        "value": $ha_proxy_ips
      },
      ".ha_proxy.skip_cert_verify": {
        "value": $skip_cert_verify
      },
      ".router.static_ips": {
        "value": $router_static_ips
      },
      ".router.disable_insecure_cookies": {
        "value": $disable_insecure_cookies
      },
      ".router.request_timeout_in_seconds": {
        "value": $router_request_timeout_seconds
      },
      ".mysql_monitor.recipient_email": {
        "value": $mysql_monitor_email
      },
      ".tcp_router.static_ips": {
        "value": $tcp_router_static_ips
      },
      ".diego_brain.static_ips": {
        "value": $ssh_static_ips
      },
      ".mysql_proxy.static_ips": {
        "value": $mysql_static_ips
      }
    }

    +

    # Credhub encryption keys
    {
      ".properties.credhub_key_encryption_passwords": {
        "value": $credhub_encryption_keys
      }
    }

    +

    # Route Services
    if $route_services == "enable" then
     {
       ".properties.route_services": {
         "value": "enable"
       },
       ".properties.route_services.enable.ignore_ssl_cert_verification": {
         "value": $ignore_ssl_cert
       }
     }
    else
     {
       ".properties.route_services": {
         "value": "disable"
       }
     }
    end

    +

    # TCP Routing
    if $tcp_routing == "enable" then
     {
       ".properties.tcp_routing": {
          "value": "enable"
        },
        ".properties.tcp_routing.enable.reservable_ports": {
          "value": $tcp_routing_ports
        }
      }
    else
      {
        ".properties.tcp_routing": {
          "value": "disable"
        }
      }
    end

    +

    # HAProxy Forward TLS
    if $haproxy_forward_tls == "enable" then
      {
        ".properties.haproxy_forward_tls": {
          "value": "enable"
        },
        ".properties.haproxy_forward_tls.enable.backend_ca": {
          "value": $haproxy_backend_ca
        }
      }
    end

    +

    {
      ".properties.networking_point_of_entry.haproxy.disable_http": {
        "value": $disable_http_proxy
      }
    }

    +

    {
      ".properties.routing_tls_termination": {
        "value": $routing_tls_termination
      }
    }

    +

    {
      ".properties.networking_point_of_entry": {
        "value": "external_non_ssl"
      }
    }

    +

    if $routing_custom_ca_certificates == "" then
      .
    else
      {
        ".properties.routing_custom_ca_certificates": {
          "value": $routing_custom_ca_certificates
        }
      }
    end

    +

    # TLS Cipher Suites
    {
      ".properties.networking_point_of_entry.external_ssl.ssl_ciphers": {
        "value": $router_tls_ciphers
      },
      ".properties.networking_point_of_entry.haproxy.ssl_ciphers": {
        "value": $haproxy_tls_ciphers
      }
    }

    +

    # SMTP Configuration
    if $smtp_address != "" then
      {
        ".properties.smtp_from": {
          "value": $smtp_from
        },
        ".properties.smtp_address": {
          "value": $smtp_address
        },
        ".properties.smtp_port": {
          "value": $smtp_port
        },
        ".properties.smtp_credentials": {
          "value": {
            "identity": $smtp_user,
            "password": $smtp_password
          }
        },
        ".properties.smtp_enable_starttls_auto": {
          "value": $smtp_enable_starttls_auto
        },
        ".properties.smtp_auth_mechanism": {
          "value": $smtp_auth_mechanism
        }
      }
    else
      .
    end

    +

    # Syslog
    if $syslog_host != "" then
      {
        ".doppler.message_drain_buffer_size": {
          "value": $syslog_drain_buffer_size
        },
        ".cloud_controller.security_event_logging_enabled": {
          "value": $enable_security_event_logging
        },
        ".properties.syslog_host": {
          "value": $syslog_host
        },
        ".properties.syslog_port": {
          "value": $syslog_port
        },
        ".properties.syslog_protocol": {
          "value": $syslog_protocol
        }
      }
    else
      .
    end

    +

    # Authentication
    if $authentication_mode == "internal" then
      {
        ".properties.uaa": {
          "value": "internal"
        }
      }
    elif $authentication_mode == "ldap" then
      {
        ".properties.uaa": {
          "value": "ldap"
        },
        ".properties.uaa.ldap.url": {
          "value": $ldap_url
        },
        ".properties.uaa.ldap.credentials": {
          "value": {
            "identity": $ldap_user,
            "password": $ldap_password
          }
        },
        ".properties.uaa.ldap.search_base": {
          "value": $ldap_search_base
        },
        ".properties.uaa.ldap.search_filter": {
          "value": $ldap_search_filter
        },
        ".properties.uaa.ldap.group_search_base": {
          "value": $ldap_group_search_base
        },
        ".properties.uaa.ldap.group_search_filter": {
          "value": $ldap_group_search_filter
        },
        ".properties.uaa.ldap.mail_attribute_name": {
          "value": $ldap_mail_attr_name
        },
        ".properties.uaa.ldap.first_name_attribute": {
          "value": $ldap_first_name_attr
        },
        ".properties.uaa.ldap.last_name_attribute": {
          "value": $ldap_last_name_attr
        }
      }
    else
      .
    end

    +

    # UAA SAML Credentials
    {
      ".uaa.service_provider_key_credentials": {
        value: {
          "cert_pem": $saml_cert_pem,
          "private_key_pem": $saml_key_pem
        }
      }
    }

    +

    # MySQL Backups
    if $mysql_backups == "s3" then
      {
        ".properties.mysql_backups": {
          "value": "s3"
        },
        ".properties.mysql_backups.s3.endpoint_url":  {
          "value": $mysql_backups_s3_endpoint_url
        },
        ".properties.mysql_backups.s3.bucket_name":  {
          "value": $mysql_backups_s3_bucket_name
        },
        ".properties.mysql_backups.s3.bucket_path":  {
          "value": $mysql_backups_s3_bucket_path
        },
        ".properties.mysql_backups.s3.access_key_id":  {
          "value": $mysql_backups_s3_access_key_id
        },
        ".properties.mysql_backups.s3.secret_access_key":  {
          "value": $mysql_backups_s3_secret_access_key
        },
        ".properties.mysql_backups.s3.cron_schedule":  {
          "value": $mysql_backups_s3_cron_schedule
        }
      }
    elif $mysql_backups == "scp" then
      {
        ".properties.mysql_backups": {
          "value": "scp"
        },
        ".properties.mysql_backups.scp.server": {
          "value": $mysql_backups_scp_server
        },
        ".properties.mysql_backups.scp.port": {
          "value": $mysql_backups_scp_port
        },
        ".properties.mysql_backups.scp.user": {
          "value": $mysql_backups_scp_user
        },
        ".properties.mysql_backups.scp.key": {
          "value": $mysql_backups_scp_key
        },
        ".properties.mysql_backups.scp.destination": {
          "value": $mysql_backups_scp_destination
        },
        ".properties.mysql_backups.scp.cron_schedule" : {
          "value": $mysql_backups_scp_cron_schedule
        }
      }
    else
      .
    end
    '
)

cf_network=$(
  jq -n \
    --arg network_name "$NETWORK_NAME" \
    --arg other_azs "$DEPLOYMENT_NW_AZS" \
    --arg singleton_az "$ERT_SINGLETON_JOB_AZ" \
    '
    {
      "network": {
        "name": $network_name
      },
      "other_availability_zones": ($other_azs | split(",") | map({name: .})),
      "singleton_availability_zone": {
        "name": $singleton_az
      }
    }
    '
)

JOB_RESOURCE_CONFIG="{
  \"backup-prepare\": { \"instances\": $BACKUP_PREPARE_INSTANCES },
  \"clock_global\": { \"instances\": $CLOCK_GLOBAL_INSTANCES },
  \"cloud_controller\": { \"instances\": $CLOUD_CONTROLLER_INSTANCES },
  \"cloud_controller_worker\": { \"instances\": $CLOUD_CONTROLLER_WORKER_INSTANCES },
  \"consul_server\": { \"instances\": $CONSUL_SERVER_INSTANCES },
  \"credhub\": { \"instances\": $CREDHUB_INSTANCES },
  \"diego_brain\": { \"instances\": $DIEGO_BRAIN_INSTANCES },
  \"diego_cell\": { \"instances\": $DIEGO_CELL_INSTANCES },
  \"diego_database\": { \"instances\": $DIEGO_DATABASE_INSTANCES },
  \"doppler\": { \"instances\": $DOPPLER_INSTANCES },
  \"ha_proxy\": { \"instances\": $HA_PROXY_INSTANCES },
  \"loggregator_trafficcontroller\": { \"instances\": $LOGGREGATOR_TRAFFICCONTROLLER_INSTANCES },
  \"mysql\": { \"instances\": $MYSQL_INSTANCES },
  \"mysql_monitor\": { \"instances\": $MYSQL_MONITOR_INSTANCES },
  \"mysql_proxy\": { \"instances\": $MYSQL_PROXY_INSTANCES },
  \"nats\": { \"instances\": $NATS_INSTANCES },
  \"nfs_server\": { \"instances\": $NFS_SERVER_INSTANCES },
  \"router\": { \"instances\": $ROUTER_INSTANCES },
  \"syslog_adapter\": { \"instances\": $SYSLOG_ADAPTER_INSTANCES },
  \"syslog_scheduler\": { \"instances\": $SYSLOG_SCHEDULER_INSTANCES },
  \"tcp_router\": { \"instances\": $TCP_ROUTER_INSTANCES },
  \"uaa\": { \"instances\": $UAA_INSTANCES }
}"

if [[ "$IAAS" == "azure" ]]; then
  JOB_RESOURCE_CONFIG=$(echo "$JOB_RESOURCE_CONFIG" | \
    jq --argjson internet_connected $INTERNET_CONNECTED \
    '. | to_entries[] | {"key": .key, value: (.value + {"internet_connected": $internet_connected}) } ' | \
    jq -s "from_entries"
  )
fi

cf_resources=$(
  jq -n \
    --arg iaas "$IAAS" \
    --arg ha_proxy_elb_name "$HA_PROXY_LB_NAME" \
    --arg ha_proxy_floating_ips "$HAPROXY_FLOATING_IPS" \
    --arg tcp_router_nsx_security_group "${TCP_ROUTER_NSX_SECURITY_GROUP}" \
    --arg tcp_router_nsx_lb_edge_name "${TCP_ROUTER_NSX_LB_EDGE_NAME}" \
    --arg tcp_router_nsx_lb_pool_name "${TCP_ROUTER_NSX_LB_POOL_NAME}" \
    --arg tcp_router_nsx_lb_security_group "${TCP_ROUTER_NSX_LB_SECURITY_GROUP}" \
    --arg tcp_router_nsx_lb_port "${TCP_ROUTER_NSX_LB_PORT}" \
    --arg router_nsx_security_group "${ROUTER_NSX_SECURITY_GROUP}" \
    --arg router_nsx_lb_edge_name "${ROUTER_NSX_LB_EDGE_NAME}" \
    --arg router_nsx_lb_pool_name "${ROUTER_NSX_LB_POOL_NAME}" \
    --arg router_nsx_lb_security_group "${ROUTER_NSX_LB_SECURITY_GROUP}" \
    --arg router_nsx_lb_port "${ROUTER_NSX_LB_PORT}" \
    --arg diego_brain_nsx_security_group "${DIEGO_BRAIN_NSX_SECURITY_GROUP}" \
    --arg diego_brain_nsx_lb_edge_name "${DIEGO_BRAIN_NSX_LB_EDGE_NAME}" \
    --arg diego_brain_nsx_lb_pool_name "${DIEGO_BRAIN_NSX_LB_POOL_NAME}" \
    --arg diego_brain_nsx_lb_security_group "${DIEGO_BRAIN_NSX_LB_SECURITY_GROUP}" \
    --arg diego_brain_nsx_lb_port "${DIEGO_BRAIN_NSX_LB_PORT}" \
    --arg mysql_nsx_security_group "${MYSQL_NSX_SECURITY_GROUP}" \
    --arg mysql_nsx_lb_edge_name "${MYSQL_NSX_LB_EDGE_NAME}" \
    --arg mysql_nsx_lb_pool_name "${MYSQL_NSX_LB_POOL_NAME}" \
    --arg mysql_nsx_lb_security_group "${MYSQL_NSX_LB_SECURITY_GROUP}" \
    --arg mysql_nsx_lb_port "${MYSQL_NSX_LB_PORT}" \
    --argjson job_resource_config "${JOB_RESOURCE_CONFIG}" \
    '
    $job_resource_config

    |

    if $ha_proxy_elb_name != "" then
      .ha_proxy |= . + { "elb_names": [ $ha_proxy_elb_name ] }
    else
      .
    end

    |

    if $ha_proxy_floating_ips != "" then
      .ha_proxy |= . + { "floating_ips": $ha_proxy_floating_ips }
    else
      .
    end

    |

    # NSX LBs

    if $tcp_router_nsx_lb_edge_name != "" then
      .tcp_router |= . + {
        "nsx_security_groups": [$tcp_router_nsx_security_group],
        "nsx_lbs": [
          {
            "edge_name": $tcp_router_nsx_lb_edge_name,
            "pool_name": $tcp_router_nsx_lb_pool_name,
            "security_group": $tcp_router_nsx_lb_security_group,
            "port": $tcp_router_nsx_lb_port
          }
        ]
      }
    else
      .
    end

    |

    if $router_nsx_lb_edge_name != "" then
      .router |= . + {
        "nsx_security_groups": [$router_nsx_security_group],
        "nsx_lbs": [
          {
            "edge_name": $router_nsx_lb_edge_name,
            "pool_name": $router_nsx_lb_pool_name,
            "security_group": $router_nsx_lb_security_group,
            "port": $router_nsx_lb_port
          }
        ]
      }
    else
      .
    end

    |

    if $diego_brain_nsx_lb_edge_name != "" then
      .diego_brain |= . + {
        "nsx_security_groups": [$diego_brain_nsx_security_group],
        "nsx_lbs": [
          {
            "edge_name": $diego_brain_nsx_lb_edge_name,
            "pool_name": $diego_brain_nsx_lb_pool_name,
            "security_group": $diego_brain_nsx_lb_security_group,
            "port": $diego_brain_nsx_lb_port
          }
        ]
      }
    else
      .
    end

    |

    # MySQL

    if $mysql_nsx_lb_edge_name != "" then
      .mysql |= . + {
        "nsx_security_groups": [$mysql_nsx_security_group],
        "nsx_lbs": [
          {
            "edge_name": $mysql_nsx_lb_edge_name,
            "pool_name": $mysql_nsx_lb_pool_name,
            "security_group": $mysql_nsx_lb_security_group,
            "port": $mysql_nsx_lb_port
          }
        ]
      }
    else
      .
    end
    '
)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --username "$OPS_MGR_USR" \
  --password "$OPS_MGR_PWD" \
  --skip-ssl-validation \
  configure-product \
  --product-name cf \
  --product-properties "$cf_properties" \
  --product-network "$cf_network" \
  --product-resources "$cf_resources"
