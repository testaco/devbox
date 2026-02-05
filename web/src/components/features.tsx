import { Box, Zap, Share2, Lock, RefreshCw, Layers } from 'lucide-react'

const features = [
  {
    icon: Box,
    title: 'Isolated Containers',
    description:
      'Each project runs in its own isolated environment. No more dependency conflicts or version mismatches.',
  },
  {
    icon: Zap,
    title: 'Lightning Fast',
    description:
      'Spin up a new environment in seconds, not minutes. Optimized for developer productivity.',
  },
  {
    icon: Share2,
    title: 'Shareable',
    description:
      'Share your entire dev environment with your team. Everyone gets the exact same setup.',
  },
  {
    icon: RefreshCw,
    title: 'Reproducible',
    description: 'Define your environment as code. Get the same result every time, on any machine.',
  },
  {
    icon: Lock,
    title: 'Secure',
    description: 'Sandboxed environments protect your system. Experiment freely without risk.',
  },
  {
    icon: Layers,
    title: 'Language Agnostic',
    description: 'Supports any language or framework. Node, Python, Go, Rust, and more out of the box.',
  },
]

export function Features() {
  return (
    <section className="py-24 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold mb-4 text-balance">
            Everything you need for
            <span className="text-primary"> modern development</span>
          </h2>
          <p className="text-muted-foreground text-lg max-w-2xl mx-auto">
            Built for developers who value their time and sanity.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="group relative p-6 rounded-lg border border-border bg-card hover:border-primary/50 transition-colors"
            >
              <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 transition-colors">
                <feature.icon className="w-6 h-6 text-primary" />
              </div>
              <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
              <p className="text-muted-foreground text-sm leading-relaxed">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
