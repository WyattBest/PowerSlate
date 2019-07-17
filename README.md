# PowerSlate
PowerSlate: An Integration

## About
A small project to synchronize applications for admission between Technolutions Slate and PowerCampus.

## Requirements
Python 3.x is required, along with a few packages available via pip. There are no known issues between different package versions.

## Usage
### Configuration
Copy `config_sample.json` to a new file, then edit the values for your environment.

### Timed sync
Execute `sync_ondemand.py`. Pass the name of the configuration file as an argument. This can be used with an external task scheduler, such as Task Scheduler in Windows.

Example for Windows PowerShell : `python.exe .\sync_ondemand.py config_sample.json`

### Trigger Sync
Execute `sync_http.py`. It will start a webserver on port 8887 that you can link to from within Slate.

The link should contain the GUID of the person as the parameter `pid`. Example: `http://server:8887/?pid=84f2060e-5d9d-437b-b5be-9558679edac4`
