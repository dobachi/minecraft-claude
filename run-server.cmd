@echo off
rem Wrapper that launches the Mming-Lab MCP server with stderr captured to logs\server.log.
rem stdout is left connected to the parent process (Claude Desktop) because MCP protocol
rem uses stdin/stdout for JSON-RPC framing — redirecting stdout would break the integration.

setlocal
set "PROJECT_DIR=%~dp0"
set "LOG_DIR=%PROJECT_DIR%logs"
set "LOG_FILE=%LOG_DIR%\server.log"
set "SERVER_JS=%PROJECT_DIR%server\dist\server.js"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

>>"%LOG_FILE%" echo.
>>"%LOG_FILE%" echo === %DATE% %TIME% server start (pid=%RANDOM%) ===

node "%SERVER_JS%" 2>>"%LOG_FILE%"
