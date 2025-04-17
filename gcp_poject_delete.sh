#!/bin/bash

# Array to store project IDs
PROJECTS=()

echo "=== GCP Project Deletion Tool ==="
echo "This script will help you delete multiple GCP projects."
echo "You can either:"
echo "1. Enter project IDs manually"
echo "2. Provide a text file with project IDs (one per line)"
echo "3. Do both"
echo ""

# Ask if user wants to load projects from a file
read -p "Do you want to load project IDs from a text file? (yes/no): " use_file

use_file=$(echo "$use_file" | tr '[:upper:]' '[:lower:]')
if [ "$use_file" = "yes" ] || [ "$use_file" = "y" ]; then
  # Get file path from user
  read -p "Enter the path to your text file: " file_path
  
  # Check if file exists
  if [ -f "$file_path" ]; then
    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
      # Skip empty lines
      if [ -z "$line" ]; then
        continue
      fi
      
      # Trim whitespace
      project_id=$(echo "$line" | xargs)
      
      # Verify if the project exists
      if gcloud projects describe "$project_id" &>/dev/null; then
        PROJECTS+=("$project_id")
        echo "Project '$project_id' from file added to deletion list."
      else
        echo "Warning: Project '$project_id' from file not found or you don't have access to it. Not added to list."
      fi
    done < "$file_path"
  else
    echo "Error: File not found at '$file_path'"
  fi
fi

# Ask if user wants to manually enter additional project IDs
read -p "Do you want to manually enter additional project IDs? (yes/no): " manual_entry

manual_entry=$(echo "$manual_entry" | tr '[:upper:]' '[:lower:]')
if [ "$manual_entry" = "yes" ] || [ "$manual_entry" = "y" ]; then
  echo "You can enter multiple project IDs, one at a time."
  echo "When finished adding projects, simply press Enter without typing a project ID."
  
  # Collect project IDs from user input
  while true; do
    read -p "Enter a project ID to delete (or press Enter to finish): " project_id
    
    # Break the loop if input is empty
    if [ -z "$project_id" ]; then
      break
    fi
    
    # Verify if the project exists
    if gcloud projects describe "$project_id" &>/dev/null; then
      PROJECTS+=("$project_id")
      echo "Project '$project_id' added to deletion list."
    else
      echo "Warning: Project '$project_id' not found or you don't have access to it. Not added to list."
    fi
  done
fi

# Display the list of projects to be deleted
echo ""
echo "You've selected the following projects for deletion:"
for project in "${PROJECTS[@]}"; do
  echo "- $project"
done

# If no projects were selected, exit
if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "No valid projects selected. Exiting."
  exit 0
fi

# Confirm deletion
echo ""
echo "WARNING: Deleting a project will remove all resources within it."
echo "Projects will enter a 30-day recovery period during which they can be restored."
read -p "Are you sure you want to delete these projects? (yes/y): " confirmation

confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')
if [ "$confirmation" != "yes" ] && [ "$confirmation" != "y" ]; then
  echo "Deletion cancelled. No projects were deleted."
  exit 0
fi

# Loop through each project and delete it
echo ""
echo "Proceeding with deletion..."
for project in "${PROJECTS[@]}"; do
  echo "Deleting project: $project"
  read -p "Confirm deletion of '$project'? (yes/y): " project_confirmation
  
  project_confirmation=$(echo "$project_confirmation" | tr '[:upper:]' '[:lower:]')
  if [ "$project_confirmation" == "yes" ] || [ "$project_confirmation" == "y" ]; then
    if gcloud projects delete "$project"; then
      echo "Project '$project' scheduled for deletion."
    else
      echo "Failed to delete project '$project'. Check permissions or project status."
    fi
  else
    echo "Skipping deletion of project '$project'."
  fi
done

echo ""
echo "Process completed. Remember that deleted projects can be restored within 30 days using:"
echo "gcloud projects undelete PROJECT_ID"