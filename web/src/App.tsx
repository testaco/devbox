import { Header } from './components/header'
import { Hero } from './components/hero'
import { Features } from './components/features'
import { Installation } from './components/installation'
import { Footer } from './components/footer'

function App() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Header />
      <main className="pt-16">
        <Hero />
        <section id="features">
          <Features />
        </section>
        <section id="install">
          <Installation />
        </section>
      </main>
      <Footer />
    </div>
  )
}

export default App
