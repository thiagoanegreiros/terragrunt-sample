package terragrunt.generate_block_contract

import rego.v1

deny contains msg if {
	some name
	block := input.generate[name][_]
	not endswith(block.path, ".tf")
	msg := sprintf("[tg] generate.%s: path '%s' must end in '.tf'", [name, block.path])
}

deny contains msg if {
	some name
	block := input.generate[name][_]
	block.if_exists != "overwrite_terragrunt"
	msg := sprintf("[tg] generate.%s: if_exists must be 'overwrite_terragrunt', got '%s'", [name, block.if_exists])
}
