package terraform.variables

import rego.v1

# HCL2 parser wraps variable configs in arrays — access via [_]

deny contains msg if {
  some name
  variable := input.variable[name][_]
  not variable.description
  msg := sprintf("[vars] variable '%s': missing 'description'", [name])
}

deny contains msg if {
  some name
  variable := input.variable[name][_]
  variable.description == ""
  msg := sprintf("[vars] variable '%s': 'description' must not be empty", [name])
}

deny contains msg if {
  some name
  variable := input.variable[name][_]
  not variable.type
  msg := sprintf("[vars] variable '%s': missing 'type'", [name])
}
