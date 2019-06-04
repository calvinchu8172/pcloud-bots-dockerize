#!/bin/bash

eval god -c bot.god -D &
eval ruby bot_echo.rb