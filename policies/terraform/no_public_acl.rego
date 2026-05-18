package terraform.s3

import rego.v1

public_acls := {"public-read", "public-read-write", "authenticated-read"}

deny contains msg if {
  some name
  config := input.resource.aws_s3_bucket_acl[name][_]
  config.acl in public_acls
  msg := sprintf("[s3] aws_s3_bucket_acl.%s: ACL '%s' exposes data publicly", [name, config.acl])
}

deny contains msg if {
  some name
  config := input.resource.aws_s3_bucket_public_access_block[name][_]
  config.block_public_acls == false
  msg := sprintf("[s3] aws_s3_bucket_public_access_block.%s: 'block_public_acls' must be true", [name])
}

deny contains msg if {
  some name
  config := input.resource.aws_s3_bucket_public_access_block[name][_]
  config.block_public_policy == false
  msg := sprintf("[s3] aws_s3_bucket_public_access_block.%s: 'block_public_policy' must be true", [name])
}
