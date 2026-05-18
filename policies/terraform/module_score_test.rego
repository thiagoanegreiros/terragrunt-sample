package terraform.module_score_test

import future.keywords.if

# ═══════════════════════════════════════════════════════════════
#  Fixture — módulo simples: muitos resources, mas interface limpa
#  Esperado: score baixo (resources têm peso leve)
# ═══════════════════════════════════════════════════════════════
mock_fat_but_simple := {
  "resource": {
    "aws_subnet": {
      "a": {}, "b": {}, "c": {}, "d": {},
      "e": {}, "f": {}, "g": {}, "h": {},
      "i": {}, "j": {}, "k": {}, "l": {},
      "m": {}, "n": {}, "o": {}, "p": {},
      "q": {}, "r": {}, "s": {}, "t": {},
      "u": {}, "v": {}, "w": {},
    },
  },
  "variable": {
    "vpc_id": {"description": "VPC id", "default": null},
    "cidr_blocks": {"description": "List of CIDRs"},
  },
  "output": {
    "subnet_ids": {},
  },
}
# score esperado: 23*0.5 + 2*0.3 + 1*0.2 = 11.5 + 0.6 + 0.2 = ~12 → apenas WARN, não DENY

# ═══════════════════════════════════════════════════════════════
#  Fixture — módulo complexo: poucos resources mas lógica pesada
# ═══════════════════════════════════════════════════════════════
mock_complex_small := {
  "resource": {
    "aws_security_group": {
      "main": {
        "depends_on": ["aws_vpc.main"],
        "dynamic": {
          "ingress": {},
          "egress":  {},
        },
      },
    },
    "aws_iam_role": {
      "app": {
        "depends_on": ["aws_security_group.main"],
        "dynamic": {
          "inline_policy": {},
        },
      },
    },
    "aws_lb": {
      "main": {
        "count": 1,
      },
    },
    "aws_lb_target_group": {
      "blue":  {"for_each": {}},
      "green": {"for_each": {}},
    },
  },
  "variable": {
    "env":          {},
    "vpc_id":       {},
    "ingress_rules":{},
    "egress_rules": {},
    "app_name":     {},
    "cert_arn":     {},
    "extra_tags":   {},
  },
  "output": {
    "lb_dns":    {},
    "sg_id":     {},
    "role_arn":  {},
  },
  "locals": {
    "computed": {
      "name_prefix": {},
      "common_tags": {},
      "merged_rules": {},
      "env_config":  {},
    },
  },
  "module": {
    "logging": {},
    "alarms":  {},
  },
  "data": {
    "aws_caller_identity": {"current": {}},
    "aws_region":          {"current": {}},
  },
}
# score esperado:
#   resources=5 * 0.5 = 2.5
#   variables=7 * 0.3 = 2.1
#   outputs=3  * 0.2 = 0.6
#   dynamic=3  * 3.0 = 9
#   depends_on=2 * 2.0 = 4
#   locals=4   * 0.3 = 1.2
#   modules=2  * 2.0 = 4
#   data=2     * 1.0 = 2
#   required_vars=7 * 1.5 = 10.5
#   mixed_iteration = 4.0
#   TOTAL ≈ 40 → DENY

# ═══════════════════════════════════════════════════════════════
#  Fixture — módulo saudável
# ═══════════════════════════════════════════════════════════════
mock_healthy := {
  "resource": {
    "aws_vpc": {"main": {}},
    "aws_subnet": {
      "pub":  {},
      "priv": {},
    },
  },
  "variable": {
    "vpc_cidr": {"default": "10.0.0.0/16", "description": "CIDR"},
    "env":      {"default": "dev",         "description": "Environment"},
  },
  "output": {
    "vpc_id":     {},
    "subnet_ids": {},
  },
}
# score esperado: 3*0.5 + 2*0.3 + 2*0.2 = 1.5 + 0.6 + 0.4 = ~2 → PASS

# ═══════════════════════════════════════════════════════════════
#  Testes
# ═══════════════════════════════════════════════════════════════

# Módulo gordo mas simples: não deve gerar DENY
test_fat_simple_no_deny if {
  count(data.terraform.module_score.deny) == 0 with input as mock_fat_but_simple
}

# Módulo complexo pequeno: deve gerar DENY
test_complex_small_deny if {
  count(data.terraform.module_score.deny) > 0 with input as mock_complex_small
}

# Módulo saudável: sem warn nem deny
test_healthy_clean if {
  count(data.terraform.module_score.deny) == 0 with input as mock_healthy
  count(data.terraform.module_score.warn) == 0 with input as mock_healthy
}

# Score do módulo complexo deve ser > 30
test_complex_score_above_threshold if {
  data.terraform.module_score.score > 30 with input as mock_complex_small
}

# Score do módulo saudável deve ser < 15
test_healthy_score_below_warn if {
  data.terraform.module_score.score < 15 with input as mock_healthy
}
