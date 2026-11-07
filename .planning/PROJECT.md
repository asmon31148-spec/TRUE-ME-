# True Me — AI-Powered All-in-One Study App

## Project Overview
True Me is a 100% free, AI-powered study companion designed for university and college students, built in Flutter (iOS, Android, and Web). The core companion is **Sage (the Mother AI)**, an adaptive AI mentor that conducts daily morning analysis of each student's progress, computes spaced repetition (SM-2) schedules, flags weak topics, and generates personalized daily study plans.

## Core Tenets & Rules
1. **100% Free**: Zero cost for end users, no paid tiers, built within free-tier limits.
2. **Provider Diversification**: Never rely on a single AI provider.
   - **Gemini 1.5 Flash**: Dedicated to Sage's daily morning reasoning and RAG vector embeddings (`text-embedding-004`).
   - **Groq LLaMA 3.1 8B / 70B & Whisper Large v3**: High volume tasks (quizzes, flashcards, YouTube transcripts, RAG chat, audio transcription).
   - **Cloudflare Workers AI**: Text & web summarization.
   - **Pollinations.ai (FLUX)**: Flashcard visual generation (unlimited, keyless).
   - **On-Device Engines**: ML Kit for OCR; Flutter `speech_to_text` and `flutter_tts` for voice sessions with 0 API cost.
3. **Storage Strategy**: Raw files (PDFs, recordings, images) are stored in the user's own cloud drive (Google Drive / OneDrive / Dropbox). Supabase PostgreSQL + `pgvector` stores only metadata, text chunks, and vector embeddings.
4. **UI Design Language**: Apple Liquid Glass (glassmorphism, subtle blur, specular edge highlight, translucent frosted sheets). Reference: `liquidGL_reference`.

## Architecture & Tech Stack
- **Frontend**: Flutter (Riverpod state management, GoRouter, flutter_quill, graphview, flutter_animate, fl_chart).
- **Backend / Auth / Cloud**: Firebase Auth, Cloud Firestore, Firebase Cloud Messaging (FCM).
- **Vector DB**: Supabase PostgreSQL with `pgvector` (768 dimensions for Gemini embeddings).
- **AI Router**: Multi-tiered fallback chain with graceful degradation.
