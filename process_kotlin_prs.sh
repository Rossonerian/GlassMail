#!/bin/bash
for pr in 10 13; do
  echo "Processing PR $pr"
  gh pr checkout $pr
  git rebase main
  if [ $? -ne 0 ]; then
    echo "Rebase failed for $pr"
    git rebase --abort
    exit 1
  fi
  
  ./gradlew test || exit 1
  gh pr merge $pr --squash -d || exit 1
  git checkout main
  git pull
done
