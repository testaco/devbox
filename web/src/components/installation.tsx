'use client';

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Check, Copy, Terminal } from 'lucide-react'

const installCommands = [
  {
    label: 'macOS',
    command: 'curl -fsSL https://get.devbox.sh | bash',
  },
  {
    label: 'Linux',
    command: 'curl -fsSL https://get.devbox.sh | bash',
  },
  {
    label: 'Nix',
    command: 'nix profile install github:testaco/devbox',
  },
]

const quickStart = [
  { step: 1, command: 'devbox init', description: 'Initialize a new devbox in your project' },
  { step: 2, command: 'devbox add nodejs python', description: 'Add the packages you need' },
  { step: 3, command: 'devbox shell', description: 'Start your isolated environment' },
]

export function Installation() {
  const [activeTab, setActiveTab] = useState(0)
  const [copied, setCopied] = useState(false)

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <section className="py-24 px-6 border-t border-border">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold mb-4 text-balance">
            Get started in
            <span className="text-primary"> under a minute</span>
          </h2>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            Install devbox and create your first isolated environment with just a few commands.
          </p>
        </div>

        {/* Install command */}
        <div className="mb-16">
          <div className="flex items-center gap-2 mb-4">
            <Terminal className="w-5 h-5 text-primary" />
            <span className="font-medium">Install devbox</span>
          </div>

          <div className="bg-card border border-border rounded-lg overflow-hidden">
            <div className="flex border-b border-border">
              {installCommands.map((cmd, index) => (
                <button
                  key={cmd.label}
                  onClick={() => setActiveTab(index)}
                  className={`px-4 py-2 text-sm font-medium transition-colors ${
                    activeTab === index
                      ? 'bg-secondary text-foreground'
                      : 'text-muted-foreground hover:text-foreground'
                  }`}
                >
                  {cmd.label}
                </button>
              ))}
            </div>
            <div className="p-4 flex items-center justify-between gap-4">
              <code className="font-mono text-sm text-foreground">
                {installCommands[activeTab].command}
              </code>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => copyToClipboard(installCommands[activeTab].command)}
                className="shrink-0"
              >
                {copied ? <Check className="w-4 h-4 text-primary" /> : <Copy className="w-4 h-4" />}
              </Button>
            </div>
          </div>
        </div>

        {/* Quick start */}
        <div>
          <div className="flex items-center gap-2 mb-4">
            <Terminal className="w-5 h-5 text-primary" />
            <span className="font-medium">Quick start</span>
          </div>

          <div className="space-y-4">
            {quickStart.map((item) => (
              <div
                key={item.step}
                className="flex items-start gap-4 p-4 bg-card border border-border rounded-lg"
              >
                <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                  <span className="text-sm font-bold text-primary">{item.step}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <code className="font-mono text-sm text-primary">{item.command}</code>
                  <p className="text-sm text-muted-foreground mt-1">{item.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* CTA */}
        <div className="mt-16 text-center">
          <Button size="lg" className="h-12 px-8 text-base font-medium" asChild>
            <a
              href="https://github.com/testaco/devbox#readme"
              target="_blank"
              rel="noopener noreferrer"
            >
              Read the Documentation
            </a>
          </Button>
        </div>
      </div>
    </section>
  )
}
