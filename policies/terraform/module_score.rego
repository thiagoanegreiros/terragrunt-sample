package terraform.module_score

import future.keywords.if
import future.keywords.in

# ═══════════════════════════════════════════════════════════════
#  CONFIGURAÇÃO — ajuste os pesos e thresholds conforme seu contexto
# ═══════════════════════════════════════════════════════════════

# Pesos de cada fator (0 = ignorado, valores maiores = mais penalizante)
weights := {
  # Tamanho
  "resource_count":      0.5,   # cada resource adiciona 0.5pt
  "variable_count":      0.3,   # cada variável adiciona 0.3pt
  "output_count":        0.2,   # cada output adiciona 0.2pt

  # Complexidade lógica
  "dynamic_block":       3.0,   # cada dynamic block adiciona 3pt
  "depends_on":          2.0,   # cada depends_on explícito adiciona 2pt
  "locals_count":        0.3,   # cada local adiciona 0.3pt

  # Acoplamento
  "module_call":         2.0,   # cada module{} chamado adiciona 2pt
  "data_source":         1.0,   # cada data source adiciona 1pt
  "required_variable":   1.5,   # cada variável sem default adiciona 1.5pt (interface rígida)

  # Mistura de iteração (count + for_each no mesmo módulo)
  "mixed_iteration":     4.0,   # penalidade fixa se misturar count e for_each
}

# Score acima deste valor = DENY (bloqueia pipeline)
deny_threshold := 40

# Score acima deste valor = WARN (apenas alerta)
warn_threshold := 25

# ═══════════════════════════════════════════════════════════════
#  COLETA DE MÉTRICAS
# ═══════════════════════════════════════════════════════════════

resource_count := count({addr |
  some rtype, rname
  input.resource[rtype][rname]
  addr := sprintf("%s.%s", [rtype, rname])
})

variable_count := count({name |
  some name
  input.variable[name]
})

output_count := count({name |
  some name
  input.output[name]
})

dynamic_block_count := count({addr |
  some rtype, rname, bname
  input.resource[rtype][rname].dynamic[bname]
  addr := sprintf("%s.%s.dynamic.%s", [rtype, rname, bname])
})

depends_on_count := count({addr |
  some rtype, rname
  input.resource[rtype][rname].depends_on
  addr := sprintf("%s.%s", [rtype, rname])
})

locals_count := count({name |
  some name
  input.locals[_][name]
})

module_call_count := count({name |
  some name
  input.module[name]
})

data_source_count := count({addr |
  some dtype, dname
  input.data[dtype][dname]
  addr := sprintf("data.%s.%s", [dtype, dname])
})

required_variable_count := count({name |
  some name
  input.variable[name]
  every obj in input.variable[name] {
    not "default" in object.keys(obj)
  }
})

has_mixed_iteration if {
  some rtype1, rname1
  input.resource[rtype1][rname1].count
  some rtype2, rname2
  input.resource[rtype2][rname2].for_each
}

mixed_iteration_penalty := weights["mixed_iteration"] if has_mixed_iteration
mixed_iteration_penalty := 0                           if not has_mixed_iteration

# ═══════════════════════════════════════════════════════════════
#  CÁLCULO DO SCORE
# ═══════════════════════════════════════════════════════════════

score := round(
  (resource_count        * weights["resource_count"])     +
  (variable_count        * weights["variable_count"])     +
  (output_count          * weights["output_count"])       +
  (dynamic_block_count   * weights["dynamic_block"])      +
  (depends_on_count      * weights["depends_on"])         +
  (locals_count          * weights["locals_count"])       +
  (module_call_count     * weights["module_call"])        +
  (data_source_count     * weights["data_source"])        +
  (required_variable_count * weights["required_variable"]) +
  mixed_iteration_penalty
)

# ═══════════════════════════════════════════════════════════════
#  BREAKDOWN — detalhes para debugging
# ═══════════════════════════════════════════════════════════════

breakdown := {
  "resources":          {"count": resource_count,          "contribution": round(resource_count          * weights["resource_count"])},
  "variables":          {"count": variable_count,          "contribution": round(variable_count          * weights["variable_count"])},
  "outputs":            {"count": output_count,            "contribution": round(output_count            * weights["output_count"])},
  "dynamic_blocks":     {"count": dynamic_block_count,     "contribution": round(dynamic_block_count     * weights["dynamic_block"])},
  "depends_on":         {"count": depends_on_count,        "contribution": round(depends_on_count        * weights["depends_on"])},
  "locals":             {"count": locals_count,            "contribution": round(locals_count            * weights["locals_count"])},
  "module_calls":       {"count": module_call_count,       "contribution": round(module_call_count       * weights["module_call"])},
  "data_sources":       {"count": data_source_count,       "contribution": round(data_source_count       * weights["data_source"])},
  "required_variables": {"count": required_variable_count, "contribution": round(required_variable_count * weights["required_variable"])},
  "mixed_iteration":    {"count": 1,                       "contribution": round(mixed_iteration_penalty)},
}

# ═══════════════════════════════════════════════════════════════
#  REGRAS
# ═══════════════════════════════════════════════════════════════

deny contains msg if {
  score > deny_threshold
  msg := sprintf(
    "MODULE_SCORE: score=%d (limite=%d)\n  Resources=%d(+%d) Variables=%d(+%d) Outputs=%d(+%d)\n  Dynamic=%d(+%d) DependsOn=%d(+%d) Locals=%d(+%d)\n  ModuleCalls=%d(+%d) DataSources=%d(+%d) RequiredVars=%d(+%d) MixedIteration(+%d)",
    [
      score, deny_threshold,
      breakdown.resources.count,          breakdown.resources.contribution,
      breakdown.variables.count,          breakdown.variables.contribution,
      breakdown.outputs.count,            breakdown.outputs.contribution,
      breakdown.dynamic_blocks.count,     breakdown.dynamic_blocks.contribution,
      breakdown.depends_on.count,         breakdown.depends_on.contribution,
      breakdown.locals.count,             breakdown.locals.contribution,
      breakdown.module_calls.count,       breakdown.module_calls.contribution,
      breakdown.data_sources.count,       breakdown.data_sources.contribution,
      breakdown.required_variables.count, breakdown.required_variables.contribution,
      breakdown.mixed_iteration.contribution,
    ]
  )
}

warn contains msg if {
  score > warn_threshold
  score <= deny_threshold
  msg := sprintf(
    "MODULE_SCORE: score=%d está acima do aviso (warn=%d, deny=%d). Principais fatores: dynamic=%d, depends_on=%d, required_vars=%d.",
    [score, warn_threshold, deny_threshold, dynamic_block_count, depends_on_count, required_variable_count]
  )
}
