#!/bin/bash

eval cron
eval whenever --update-crontab
eval god -c bot.god -D
