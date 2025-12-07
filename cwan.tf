data "aws_networkmanager_core_network_policy_document" "basic" {
  core_network_configuration {
    vpn_ecmp_support   = false
    asn_ranges         = var.core_network_config.asn_ranges
    inside_cidr_blocks = var.core_network_config.inside_cidr_blocks
    dynamic "edge_locations" {
      for_each = { for el in var.core_network_config.edge_locations : el.region => el }
      content {
        location           = edge_locations.key
        asn                = edge_locations.value.asn
        inside_cidr_blocks = edge_locations.value.inside_cidr_blocks
      }
    }
  }

  dynamic "segments" {
    for_each = local.cwn_all_segments
    content {
      name                          = format("cwnsgm%s%s", title(var.project_code), title(segments.key))
      description                   = format("%s %s", title(var.project_name), segments.value["description"])
      require_attachment_acceptance = segments.value["require_attachment_acceptance"]
      isolate_attachments           = segments.value["isolate_attachments"]
    }
  }

  network_function_groups {
    name                          = format("cwnnfg%sIns", title(var.project_code))
    description                   = format("%s Inspection", title(var.project_name))
    require_attachment_acceptance = true
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "or"
    conditions {
      key      = "tec:cwnnfg"
      operator = "equals"
      type     = "tag-value"
      value    = format("cwnnfg%sIns", title(var.project_code))
    }
    action {
      add_to_network_function_group = format("cwnnfg%sIns", title(var.project_code))
    }
  }

  attachment_policies {
    rule_number     = 200
    condition_logic = "or"
    conditions {
      type = "tag-exists"
      key  = "tec:cwnsgm"
    }
    action {
      association_method = "tag"
      tag_value_of_key   = "tec:cwnsgm"
    }
  }
}

data "aws_networkmanager_core_network_policy_document" "full" {
  core_network_configuration {
    vpn_ecmp_support   = false
    asn_ranges         = var.core_network_config.asn_ranges
    inside_cidr_blocks = var.core_network_config.inside_cidr_blocks
    dynamic "edge_locations" {
      for_each = { for el in var.core_network_config.edge_locations : el.region => el }
      content {
        location           = edge_locations.key
        asn                = edge_locations.value.asn
        inside_cidr_blocks = edge_locations.value.inside_cidr_blocks
      }
    }
  }

  dynamic "segments" {
    for_each = local.cwn_all_segments
    content {
      name                          = format("cwnsgm%s%s", title(var.project_code), title(segments.key))
      description                   = format("%s %s", title(var.project_name), segments.value["description"])
      require_attachment_acceptance = segments.value["require_attachment_acceptance"]
      isolate_attachments           = segments.value["isolate_attachments"]
    }
  }

  network_function_groups {
    name                          = format("cwnnfg%sIns", title(var.project_code))
    description                   = format("%s Inspection", title(var.project_name))
    require_attachment_acceptance = true
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "or"
    conditions {
      key      = "tec:cwnnfg"
      operator = "equals"
      type     = "tag-value"
      value    = format("cwnnfg%sIns", title(var.project_code))
    }
    action {
      add_to_network_function_group = format("cwnnfg%sIns", title(var.project_code))
    }
  }

  attachment_policies {
    rule_number     = 200
    condition_logic = "or"
    conditions {
      type = "tag-exists"
      key  = "tec:cwnsgm"
    }
    action {
      association_method = "tag"
      tag_value_of_key   = "tec:cwnsgm"
    }
  }

  /*
  dynamic "segment_actions" {
    for_each = local.cwn_all_segments
    content {
      segment                 = format("cwnsgm%s%s", title(var.project_code), title(segment_actions.key))
      action                  = "create-route"
      destination_cidr_blocks = local.blackhole_cidrs
      destinations            = ["blackhole"]
    }
  }
  */

  dynamic "segment_actions" {
    for_each = { for s in local.cwn_basic_segments : s.name => s if length(s.share_with) > 0 }
    content {
      segment    = format("cwnsgm%s%s", title(var.project_code), title(segment_actions.key))
      action     = "share"
      mode       = "attachment-route"
      share_with = [for s in segment_actions.value.share_with : format("cwnsgm%s%s", title(var.project_code), title(s))]
    }
  }

  dynamic "segment_actions" {
    for_each = { for i in local.reverse_segment_sharing : "${i.segment}${i.share_with}" => i }
    content {
      segment    = format("cwnsgm%s%s", title(var.project_code), title(segment_actions.value.segment))
      action     = "share"
      mode       = "attachment-route"
      share_with = [format("cwnsgm%s%s", title(var.project_code), title(segment_actions.value.share_with))]
    }
  }


  dynamic "segment_actions" {
    for_each = { for s, s_data in local.cwn_all_segments : s => s_data if !contains(["nva", "shr"], s) }
    content {
      segment = format("cwnsgm%s%s", title(var.project_code), title(segment_actions.key))
      action  = "send-via"
      mode    = "single-hop"
      via {
        network_function_groups = [format("cwnnfg%sIns", title(var.project_code))]
        dynamic "with_edge_override" {
          for_each = flatten([for el in var.core_network_config.edge_locations : [for eosv in el.edge_overrides.send_via : merge(eosv, { edge_sets = setproduct([el.region], eosv.regions) })] if el.edge_overrides.send_via != null])
          content {
            edge_sets         = with_edge_override.value.edge_sets
            use_edge_location = with_edge_override.value.use_edge_location
          }
        }
      }
      when_sent_to {
        segments = [for s, s_data in local.cwn_all_segments : format("cwnsgm%s%s", title(var.project_code), title(s)) if !contains(["nva", "shr"], s)]
      }
    }
  }

  dynamic "segment_actions" {
    for_each = { for s in var.core_network_config.segments : s.name => s }
    content {
      segment = format("cwnsgm%s%s", title(var.project_code), title(segment_actions.key))
      action  = "send-to"
      via {
        network_function_groups = [format("cwnnfg%sIns", title(var.project_code))]
        dynamic "with_edge_override" {
          for_each = {
            for k, v in transpose(
              { for el in var.core_network_config.edge_locations : el.region => [el.edge_overrides.send_to] if el.edge_overrides.send_to != null }
            ) : k => [for j in v : [j]]
          }
          content {
            edge_sets         = with_edge_override.value
            use_edge_location = with_edge_override.key
          }
        }
      }
    }
  }
}

locals {
  cwan_policy = merge(jsondecode(data.aws_networkmanager_core_network_policy_document.full.json), local.extra_cwan_policy)
  extra_cwan_policy = {
    "version" = "2025.11"
    "routing-policies" = [
      {
        "routing-policy-name"        = "secondaryCidrFiltering"
        "routing-policy-description" = "Attachment IPv4 secondary CIDR block filtering"
        "routing-policy-direction"   = "inbound"
        "routing-policy-number"      = 100
        "routing-policy-rules" = [
          {
            "rule-number" = 100
            "rule-definition" = {
              "match-conditions" = [
                {
                  "type"  = "prefix-in-cidr"
                  "value" = "100.64.0.0/10"
                }
              ]
              "condition-logic" = "or"
              "action" = {
                "type" = "drop"
              }
            }
          }
        ]
      },
      {
        "routing-policy-name"        = "summarizeCloud"
        "routing-policy-description" = "Summarize Cloud CIDRs"
        "routing-policy-direction"   = "outbound"
        "routing-policy-number"      = 200
        "routing-policy-rules" = [
          for i, el in var.core_network_config.edge_locations :
          {
            "rule-number" = 100 + i * 10
            "rule-definition" = {
              "match-conditions" = [
                {
                  "type" : "prefix-in-cidr"
                  "value" : el.cidr
                }
              ]
              "condition-logic" : "or"
              "action" : {
                "type" : "summarize"
                "value" : el.cidr
              }
            }
          }
        ]
      },
      {
        "routing-policy-name"        = "blockSDWanTransit"
        "routing-policy-description" = "Block SDWan Transit CIDRs"
        "routing-policy-direction"   = "inbound"
        "routing-policy-number"      = 300
        "routing-policy-rules" = [
          {
            "rule-number" = 100
            "rule-definition" = {
              "match-conditions" = [
                for cidr in local.sdw_cidrs :
                { "type" = "prefix-equals", "value" = cidr }
              ]
              "condition-logic" = "or"
              "action" = {
                "type" = "drop"
              }
            }
          }
        ]
      },
      {
        "routing-policy-name"        = "blockInsideCidrs"
        "routing-policy-description" = "Block Inside CIDRs"
        "routing-policy-direction"   = "inbound"
        "routing-policy-number"      = 400
        "routing-policy-rules" = [
          {
            "rule-number" = 100
            "rule-definition" = {
              "match-conditions" = [
                for cidr in var.core_network_config.inside_cidr_blocks :
                { "type" = "prefix-in-cidr", "value" = cidr }
              ]
              "condition-logic" = "or"
              "action" = {
                "type" = "drop"
              }
            }
          }
        ]
      }
    ]
    "attachment-routing-policy-rules" : [
      {
        "rule-number" : 100,
        "conditions" : [
          {
            "type" : "routing-policy-label"
            "value" : "vpcAttachments"
          }
        ],
        "action" : {
          "associate-routing-policies" : [
            "secondaryCidrFiltering"
          ]
        }
      },
      {
        "rule-number" : 110,
        "conditions" : [
          {
            "type" : "routing-policy-label"
            "value" : "hybridAttachments"
          }
        ],
        "action" : {
          "associate-routing-policies" : [
            "summarizeCloud",
            "blockSDWanTransit",
            "blockInsideCidrs"
          ]
        }
      }
    ]
  }
}

# AWS Cloud WAN Global Network
resource "aws_networkmanager_global_network" "this" {
  description = format("Global Network %s", title(var.project_name))

  tags = {
    Name = format("%s-cwngln", var.project_code)
  }
}

# AWS Cloud Wan Core Network
resource "aws_networkmanager_core_network" "this" {
  description          = format("Core Network %s", title(var.project_name))
  global_network_id    = aws_networkmanager_global_network.this.id
  create_base_policy   = true
  base_policy_document = jsonencode(jsondecode(data.aws_networkmanager_core_network_policy_document.basic.json))

  tags = {
    Name = format("%s-cwncnt", var.project_code)
  }
}

# AWS Cloud WAN Core Network Policy Attachment
resource "aws_networkmanager_core_network_policy_attachment" "this" {
  core_network_id = aws_networkmanager_core_network.this.id
  //policy_document = jsonencode(jsondecode(data.aws_networkmanager_core_network_policy_document.full.json))
  policy_document = jsonencode(local.cwan_policy)
}

