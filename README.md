# ResumeCraft AI • Smart ATS 75% Gate & City Aligner Studio

> **An AI-powered ATS resume matching and tailoring engine built with Flutter, Riverpod, and Clean Architecture.**

---

## 🌟 Key Features

1. **ATS Match Analysis & 75% Unlock Gate**
   - Evaluates compatibility between candidate resumes and Job Requirements (JD).
   - Generates an animated circular gauge scoring Technical Skills, Domain Experience, and Location Alignment.
   - **Core Business Rule**: If the score is **≥ 75%**, unlocks the **"Update Resume According to Job Description"** action! If below 75%, highlights missing keywords and actionable suggestions (with an optional manual override switch).

2. **Smart City & Location Alignment Engine**
   - Automatically detects and extracts the target city/location from the Job Requirement (e.g., *Bengaluru, India*, *San Francisco, CA*, *London, UK*).
   - Aligns the candidate's contact header and relocation readiness to match the target market, improving regional ATS search filtering.

3. **PDF Ingestion & Arranging**
   - Upload real PDF resumes (from Downloads or any folder).
   - Parses compressed binary streams using `syncfusion_flutter_pdf` and reconstructs clean visual lines.
   - Automatically arranges extracted text into standardized sections (`PROFESSIONAL SUMMARY`, `TECHNICAL SKILLS`, `PROFESSIONAL EXPERIENCE`, `PROJECTS`, `EDUCATION`).

4. **Executive ATS PDF Re-Export**
   - Tailored resumes can be exported back into a high-impact, professional A4 PDF formatted specifically for modern Applicant Tracking Systems.
   - Built-in preview, print, and one-click clipboard copy.

5. **Dual Engine: Free Google Gemini API + Zero-Setup Offline Heuristic**
   - **Recommended Free AI**: Powered by **Google Gemini 1.5 / 2.0 Flash** (100% free tier from Google AI Studio: 15 Requests/Min, 1M Tokens/Min, 1,500 daily requests, no credit card needed).
   - **Offline Engine**: If no API key is provided, the app runs locally with an intelligent NLP heuristic engine.

---

## 🏗️ Architecture & Tech Stack

This project strictly adheres to **Clean Architecture** and **Riverpod State Management**:

```
lib/
├── core/
│   ├── constants/       # Sample demo data (Sample candidate resume & job descriptions)
│   ├── theme/           # Design system tokens, dark & light themes, Google Fonts
│   └── utils/           # PdfExtractor (Syncfusion) & PdfGenerator (Printing/PDF)
├── domain/
│   ├── entities/        # AnalysisResult, TailoredResume, ResumeInput
│   ├── repositories/    # ResumeRepository interface
│   └── use_cases/       # AnalyzeMatchUseCase, UpdateResumeUseCase, ExtractCityUseCase
├── data/
│   ├── datasources/     # AiRemoteDataSource (Gemini REST API), HeuristicLocalDataSource, SettingsLocalDataSource
│   ├── models/          # AnalysisResultDto
│   └── repositories/    # ResumeRepositoryImpl
└── presentation/
    ├── providers/       # Riverpod providers, notifiers, and state management
    ├── widgets/         # AnimatedScoreGauge, CityAlignmentCard, SkillsBreakdownCard, ApiKeyDialog, TailoredResumeView
    └── views/           # HomeScreen (Responsive desktop/mobile dashboard)
```

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.16+ or 3.24+)
- Google Chrome or macOS desktop target

### 2. Run Locally
```bash
# Get dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome

# Or run as a native macOS app
flutter run -d macos
```

### 3. Running Tests
```bash
flutter test
```

---

## 🔑 AI API Configuration

### Recommended: Google Gemini API (100% Free)
1. Go to [Google AI Studio](https://aistudio.google.com/apikey).
2. Click **Create API Key** (instant, free, no credit card required).
3. In the app:
   - Click the **"Offline / API Key"** button in the top right.
   - Paste your key (`AIzaSy...`) and click **Save API Key**.
   - Your key is stored securely in your browser's local storage (`SharedPreferences`).

*(Optional)* You can also pass the key during build time:
```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key_here
```

---

## 📤 Posting to GitHub

To push this project to GitHub:

```bash
# 1. Initialize git
git init

# 2. Add files
git add .

# 3. Create initial commit
git commit -m "feat: Initial commit of ResumeCraft AI with Flutter, Riverpod, and Clean Architecture"

# 4. Link to your GitHub repository
git remote add origin https://github.com/YOUR_USERNAME/resume_maker.git

# 5. Push to main branch
git branch -M main
git push -u origin main
```

---

## 📄 License
MIT License
