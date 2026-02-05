import { Button } from '@/components/ui/button'
import { Terminal, Github } from 'lucide-react'

export function Hero() {
  return (
    <section className="relative min-h-[90vh] flex items-center justify-center overflow-hidden">
      {/* Grid background */}
      <div className="absolute inset-0 bg-[linear-gradient(to_right,hsl(var(--border))_1px,transparent_1px),linear-gradient(to_bottom,hsl(var(--border))_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_110%)]" />

      <div className="relative z-10 max-w-5xl mx-auto px-6 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-2 mb-8 rounded-full border border-border bg-card/50 backdrop-blur-sm">
          <Terminal className="w-4 h-4 text-primary" />
          <span className="text-sm text-muted-foreground">Instant dev environments</span>
        </div>

        <h1 className="text-5xl md:text-7xl font-bold tracking-tight text-balance mb-6">
          <span className="text-foreground">Isolated Dev Environments</span>
          <br />
          <span className="text-primary">Made Simple</span>
        </h1>

        <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-10 text-pretty">
          Create reproducible, containerized development environments in seconds. Share your entire
          dev setup with a single command.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
          <Button size="lg" className="h-12 px-8 text-base font-medium">
            Get Started
          </Button>
          <Button
            variant="outline"
            size="lg"
            className="h-12 px-8 text-base font-medium gap-2 bg-transparent"
            asChild
          >
            <a href="https://github.com/testaco/devbox" target="_blank" rel="noopener noreferrer">
              <Github className="w-5 h-5" />
              View on GitHub
            </a>
          </Button>
        </div>

        {/* Terminal preview */}
        <div className="relative max-w-2xl mx-auto">
          <div className="absolute -inset-1 bg-primary/20 rounded-lg blur-xl opacity-50" />
          <div className="relative bg-card border border-border rounded-lg overflow-hidden shadow-2xl">
            <div className="flex items-center gap-2 px-4 py-3 border-b border-border bg-secondary/50">
              <div className="w-3 h-3 rounded-full bg-red-500/80" />
              <div className="w-3 h-3 rounded-full bg-yellow-500/80" />
              <div className="w-3 h-3 rounded-full bg-green-500/80" />
              <span className="ml-2 text-xs text-muted-foreground font-mono">terminal</span>
            </div>
            <div className="p-6 font-mono text-sm text-left">
              <div className="flex items-center gap-2 text-muted-foreground">
                <span className="text-primary">$</span>
                <span className="text-foreground">devbox init</span>
              </div>
              <div className="mt-2 text-muted-foreground">
                Creating devbox.json in current directory...
              </div>
              <div className="mt-1 text-primary">Done! Your devbox is ready.</div>
              <div className="mt-4 flex items-center gap-2 text-muted-foreground">
                <span className="text-primary">$</span>
                <span className="text-foreground">devbox shell</span>
              </div>
              <div className="mt-2 text-muted-foreground">Starting devbox shell...</div>
              <div className="mt-1 text-primary">
                (devbox) $<span className="ml-2 animate-pulse">_</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
