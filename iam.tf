data "aws_iam_policy_document" "ec2_role_trust_policy" {
  statement {
    sid     = "1"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

  }
}

resource "aws_iam_role" "common" {
  name               = format("%s-generic-role", var.project_code)
  path               = "/${var.project_code}/"
  assume_role_policy = data.aws_iam_policy_document.ec2_role_trust_policy.json
}

resource "aws_iam_instance_profile" "common" {
  name = format("%s-generic-profile", var.project_code)
  role = aws_iam_role.common.id
}

resource "aws_iam_role_policy_attachment" "ssm_managed_common" {
  role       = aws_iam_role.common.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
