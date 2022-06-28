[Menu](../README.md) [Home](./home.md)
## PDF Export

### When ?

When a drawing (idw, dwg) is changed to a Vault status which is marked as a "Released" state then a PDF job is triggered by powerEvents.

### What ?

The PDF job is processed with powerJobs and generates out of the drawing:
1. A PDF 
1. Uploads it to ERP
1. Uploads it to network path

### Remarks

to be sure the exported pdf is up to date, the Autodesk job "Synchronize Properties" gets processed before the pdf job.
This is guaranteed only, if there is only one active job processor!
Since "Synchronize Properties" is triggered by powerEvents, it has to be disabled in the Vault settings. If not, it gets triggered twice.
