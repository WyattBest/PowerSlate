# PowerSlate
PowerSlate: An Integration

## About
A small project to synchronize applications for admission between Technolutions Slate and PowerCampus.

## Requirements
Python 3.x is required, along with a few packages available via pip. There are no known issues between different package versions.

## Usage
### Configuration
Copy config_sample.json to a new file, then edit the values for your environment.

### Timed sync
From the command line, execute sync_ondemand.py. Pass the name of the configuration file as an argument. This can be used with an external task scheduler, such as Task Scheduler in Windows.

Windows PowerShell example: `python.exe .\sync_ondemand.py config_sample.json`

### Trigger Sync
From the command line, execute sync_http.py. It will start a webserver on port 8887 that you can link to from within Slate.
