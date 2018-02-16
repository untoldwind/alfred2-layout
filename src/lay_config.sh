#!/bin/bash

ALFRED_DIR=~/Library/Application\ Support/Alfred\ 3

# setting the data path according to the installed Alfred version
if [ -d "$ALFRED_DIR" ]; then
  DATA_PATH=./Data/de.leanovate.alfred.layout
else
  DATA_PATH=~/Library/Application\ Support/Alfred\ 2/Workflow\ Data/de.leanovate.alfred.layout
fi

# making sure path exists
if [ ! -d "$DATA_PATH" ]; then
  mkdir -p "$DATA_PATH"
fi

CSTM_LAY_CFG_FILE="$DATA_PATH"/layouts.yaml

# making sure the file exists
if [ ! -e "$CSTM_LAY_CFG_FILE" ]; then
  cp default_layouts.yaml "$CSTM_LAY_CFG_FILE"
fi

if [ "$1" = "goto" ]; then
    open "$DATA_PATH"
else
    open "$CSTM_LAY_CFG_FILE"
fi
