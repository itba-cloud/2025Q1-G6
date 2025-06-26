output "scraper_sqs_queue_url" {
  description = "URL of the Mercado scraper SQS queue"
  value       = aws_sqs_queue.scraper_queue.id
}
