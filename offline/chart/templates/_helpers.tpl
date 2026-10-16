{{- define "workshop.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workshop.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "workshop.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "workshop.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workshop.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{- define "workshop.toolsFullname" -}}
{{- printf "%s-tools" (include "workshop.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "workshop.toolsImage" -}}
{{- $tag := .Values.tools.image.tag | default (.Values.image.tag | default .Chart.AppVersion) }}
{{- printf "%s:%s" .Values.tools.image.repository $tag }}
{{- end }}
