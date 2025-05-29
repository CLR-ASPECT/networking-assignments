#!/bin/bash

list_string() {
    list=$!
    IFS=$'\n'
    string="${list[*]}"
    echo "$string"
}
