# Cloudinary Migration Plan

## Overview

This document tracks the migration from Firebase Storage to Cloudinary for photo handling in the AccessLink application.

## Post-implementation: firebase_storage removal assessment

firebase_storage is imported NOWHERE in lib/ after migration (verified), so after successful LIVE end-to-end validation it is safe to remove:
- The firebase_storage dependency from pubspec.yaml
- storage.rules file
- firebase.json storage block  
- firebase-tests Storage tests

Until live validation is complete, these artifacts are retained as OBSOLETE-FOR-PHOTOS but kept for reference.