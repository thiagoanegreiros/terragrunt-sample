package terragrunt.no_hardcoded_ids

import rego.v1

# Cognito pool ID: us-east-1_LGesP48iC
cognito_pool_pattern := `[a-z]+-[a-z]+-[0-9]+_[A-Za-z0-9]{6,}`

# ARN: arn:aws:service:region:accountid:
arn_pattern := `arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:`

# Cognito hosted UI domain: foo.auth.us-east-1.amazoncognito.com
cognito_domain_pattern := `[a-zA-Z0-9-]+\.auth\.[a-z0-9-]+\.amazoncognito\.com`

deny contains msg if {
	some name
	block := input.generate[name][_]
	regex.match(cognito_pool_pattern, block.contents)
	msg := sprintf("[tg] generate.%s: hardcoded Cognito pool ID — use SSM Parameter Store", [name])
}

deny contains msg if {
	some name
	block := input.generate[name][_]
	regex.match(arn_pattern, block.contents)
	msg := sprintf("[tg] generate.%s: hardcoded ARN — use SSM Parameter Store", [name])
}

deny contains msg if {
	some name
	block := input.generate[name][_]
	regex.match(cognito_domain_pattern, block.contents)
	msg := sprintf("[tg] generate.%s: hardcoded Cognito domain — use SSM Parameter Store", [name])
}
