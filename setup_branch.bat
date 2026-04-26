@echo off
echo Setting up development environment...
echo.

echo Initializing git repository...
git init

echo Adding all files...
git add .

echo Creating initial commit...
git commit -m "Initial setup with development workflow documentation"

echo Creating feature branch for routing overhaul...
git checkout -b feature/routing-overhaul

echo.
echo Setup complete! You are now on the feature/routing-overhaul branch.
echo.
pause
