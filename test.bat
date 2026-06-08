@echo off
chcp 65001 >nul 2>&1
title Проверка прав администратора

net session >nul 2>&1
if %errorlevel% equ 0 (
    echo [√] Скрипт запущен от имени АДМИНИСТРАТОРА.
) else (
    echo [×] Скрипт НЕ запущен от имени администратора.
)

echo.
pause