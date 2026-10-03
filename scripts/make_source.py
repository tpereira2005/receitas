#!/usr/bin/env python3
"""Gera a fonte (source.json) do SideStore/AltStore para a versão acabada de compilar.

Variáveis de ambiente: REPO, APP_VERSION, BUILD, IPA_SIZE, NOTES.
"""
import datetime
import json
import os
import sys

repo = os.environ["REPO"]
version = os.environ["APP_VERSION"]
build = os.environ["BUILD"]
size = int(os.environ["IPA_SIZE"])
notes = os.environ.get("NOTES", "").strip() or f"Versão {version}"

bundle_id = "com.tpereira.receitasfit"
releases = f"https://github.com/{repo}/releases/download"
download_url = f"{releases}/v{version}/Receitas.ipa"
icon_url = f"https://raw.githubusercontent.com/{repo}/sidestore/AppIcon.png"
screenshots = [
    f"{releases}/latest/{name}.png"
    for name in ("1-inicio", "2-receita", "38-modo-cozinhar", "39-inicio-congelador", "8-receitas", "4-alimentos", "33-definicoes")
]
date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
description = (
    "App pessoal para guardar e organizar receitas fit e saudáveis: biblioteca de alimentos com leitura de "
    "embalagens, calorias e macros calculados sozinhos, modo cozinhar com temporizadores, lembrete do "
    "congelador e cópias de segurança automáticas, com o design Liquid Glass do iOS."
)

# Notícias das versões grandes (aparecem no separador de notícias do SideStore).
news = [
    {
        "title": "Receitas 1.6",
        "identifier": "receitas-1.6",
        "caption": "Temporizadores que tocam como um alarme, mesmo em silêncio, com a contagem "
                   "no ecrã bloqueado e na Dynamic Island.",
        "date": "2026-10-03",
        "tintColor": "#10B062",
        "imageURL": f"{releases}/latest/51-live-activity.png",
        "appID": "com.tpereira.receitasfit",
        "notify": False,
    },
    {
        "title": "Receitas 1.4",
        "identifier": "receitas-1.4",
        "caption": "Modo cozinhar com temporizadores, lembrete do congelador, pesos e doses, "
                   "enquadramento com zoom e Apagadas recentemente.",
        "date": "2026-09-26",
        "tintColor": "#10B062",
        "imageURL": f"{releases}/latest/38-modo-cozinhar.png",
        "appID": "com.tpereira.receitasfit",
        "notify": False,
    },
    {
        "title": "Receitas 1.3",
        "identifier": "receitas-1.3",
        "caption": "Novo Início, filtros combinados, leitura de embalagens com o Gemini, "
                   "porções e colheres, fotografias e cópias automáticas.",
        "date": "2026-09-23",
        "tintColor": "#10B062",
        "imageURL": f"{releases}/latest/1-inicio.png",
        "appID": "com.tpereira.receitasfit",
        "notify": False,
    },
]

version_entry = {
    "version": version,
    "buildVersion": build,
    "date": date,
    "localizedDescription": notes,
    "downloadURL": download_url,
    "size": size,
    "minOSVersion": "26.0",
}

app = {
    "name": "Receitas",
    "bundleIdentifier": bundle_id,
    "developerName": repo.split("/")[0],
    "subtitle": "Receitas fit com macros automáticos",
    "localizedDescription": description,
    "iconURL": icon_url,
    "tintColor": "#10B062",
    "category": "lifestyle",
    "screenshots": screenshots,
    "versions": [version_entry],
    "appPermissions": {"entitlements": [], "privacy": {}},
    # Campos antigos, para versões mais velhas do SideStore/AltStore.
    "version": version,
    "versionDate": date,
    "versionDescription": notes,
    "downloadURL": download_url,
    "size": size,
    "screenshotURLs": screenshots,
}

source = {
    "name": "Receitas",
    "identifier": f"{bundle_id}.source",
    "subtitle": "Atualizações da app Receitas",
    "description": description,
    "iconURL": icon_url,
    "website": f"https://github.com/{repo}",
    "tintColor": "#10B062",
    "apps": [app],
    "news": news,
}

sys.stdout.reconfigure(encoding="utf-8")
json.dump(source, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
