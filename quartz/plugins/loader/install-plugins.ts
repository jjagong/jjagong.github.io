#!/usr/bin/env node
import { installPlugins, parsePluginSource } from "./gitLoader.js"
import fs from "fs"
import path from "path"
import yaml from "yaml"

interface QuartzYamlConfig {
  plugins?: Array<{
    source?: string
    enabled?: boolean
  }>
  externalPlugins?: string[]
}

function readQuartzYamlConfig(): QuartzYamlConfig {
  const configPath = path.join(process.cwd(), "quartz.config.yaml")
  const raw = fs.readFileSync(configPath, "utf-8")
  return (yaml.parse(raw) as QuartzYamlConfig) ?? {}
}

async function main() {
  const quartzConfig = readQuartzYamlConfig()
  const externalPlugins = [
    ...(quartzConfig.externalPlugins ?? []),
    ...((quartzConfig.plugins ?? [])
      .filter((plugin) => plugin.enabled !== false && typeof plugin.source === "string")
      .map((plugin) => plugin.source as string)),
  ]

  if (externalPlugins.length === 0) {
    console.log("No external plugins to install.")
    return
  }

  console.log(`Installing ${externalPlugins.length} plugin(s) from Git...`)

  const specs = externalPlugins.map((source: string) => parsePluginSource(source))
  const installed = await installPlugins(specs, { verbose: true })

  if (installed.size === externalPlugins.length) {
    console.log("✓ All plugins installed successfully")
  } else {
    console.error(`✗ Only ${installed.size}/${externalPlugins.length} plugins installed`)
    process.exit(1)
  }
}

main().catch((err) => {
  console.error("Failed to install plugins:", err)
  process.exit(1)
})
