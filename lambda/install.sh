#!/bin/sh
mkdir -p build/
pip install -r requirements.txt -t build/
cp main.py build/
cp models.py build/
cp database.py build/
cp requirements.txt build/
