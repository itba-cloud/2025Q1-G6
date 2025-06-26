output "backend_image" {
  description = "Backend image URI with immutable tag"
  value       = local.backend_image
}

output "scraper_image" {
  description = "Scraper image URI with immutable tag"
  value       = local.scraper_image
}

output "backend_image_built" {
  description = "Whether backend image was built and pushed"
  value       = var.auto_build_images ? "true" : "false"
}

output "frontend_image_built" {
  description = "Whether frontend image was built and pushed"
  value       = var.auto_build_images ? "true" : "false"
} 

output "scraper_image_built" {
  description = "Whether scraper image was built and pushed"
  value       = var.auto_build_images ? "true" : "false"
}