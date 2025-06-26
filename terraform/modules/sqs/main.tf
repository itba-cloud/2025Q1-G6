data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
resource "aws_sqs_queue" "scraper_queue" {
  name                      = "mercado-scraper-queue.fifo"
  visibility_timeout_seconds = 300  # Time a message stays "invisible" after being received
  message_retention_seconds = 86400 # 1 day
  fifo_queue                = true 
}

resource "aws_iam_policy" "ecs_sqs_access" {
  name        = "ecs-sqs-access"
  description = "Allow ECS tasks to send/receive from SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.scraper_queue.arn
      }
    ]
  })
}
