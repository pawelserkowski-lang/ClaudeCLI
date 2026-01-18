import React, { useState, useRef, useEffect } from 'react';
import { Send, Loader2, Scroll, ChevronDown, ChevronUp, Sparkles } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { safeInvoke, isTauri } from '../hooks/useTauri';

interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
}

const ChatInterface: React.FC = () => {
  const { resolvedTheme } = useTheme();
  const isLight = resolvedTheme === 'light';
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '0',
      role: 'system',
      content: '⚔ KODEKS HYDRY OTWARTY ⚔\n\nWitaj w HYDRA 10.4 - Czterogłowa Bestia gotowa do służby.\nMasz pełny dostęp do: Serena, Desktop Commander, Playwright, Agent Swarm.\n\nWpisz swoje polecenie...',
      timestamp: new Date(),
    },
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Auto-resize textarea
  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.style.height = 'auto';
      inputRef.current.style.height = Math.min(inputRef.current.scrollHeight, 150) + 'px';
    }
  }, [input]);

  // Connect to Claude CLI on mount
  useEffect(() => {
    const connect = async () => {
      try {
        if (isTauri()) {
          const yoloEnabled = localStorage.getItem('hydra_yolo') !== 'false';
          await safeInvoke('start_claude_session', { yoloMode: yoloEnabled });
          setIsConnected(true);
        } else {
          // Browser mode - simulate connection
          setIsConnected(true);
        }
      } catch (e) {
        console.error('Failed to connect:', e);
        setMessages(prev => [...prev, {
          id: Date.now().toString(),
          role: 'system',
          content: `⚠ Nie można połączyć z Claude CLI: ${e}`,
          timestamp: new Date(),
        }]);
      }
    };
    connect();
  }, []);

  const sendMessage = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: input.trim(),
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      let response: string;

      if (isTauri()) {
        response = await safeInvoke<string>('send_to_claude', { message: userMessage.content });
      } else {
        // Browser mode - mock response
        await new Promise(resolve => setTimeout(resolve, 1500));
        response = getMockResponse(userMessage.content);
      }

      setMessages(prev => [...prev, {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: response,
        timestamp: new Date(),
      }]);
    } catch (e) {
      setMessages(prev => [...prev, {
        id: (Date.now() + 1).toString(),
        role: 'system',
        content: `⚠ Błąd: ${e instanceof Error ? e.message : String(e)}`,
        timestamp: new Date(),
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Messages Area */}
      <div className="flex-1 overflow-auto p-4 space-y-4">
        {messages.map((msg) => (
          <MessageBubble key={msg.id} message={msg} isLight={isLight} />
        ))}

        {isLoading && (
          <div className="flex items-center gap-3 p-4">
            <div className={`flex items-center gap-2 text-sm font-cinzel ${
              isLight ? 'text-amber-600' : 'text-amber-500'
            }`}>
              <Loader2 className="animate-spin" size={16} />
              <span>HYDRA przetwarza...</span>
              <span className="text-xs opacity-50">ᚠᚢᚦᚨᚱᚲ</span>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div className={`p-4 border-t ${
        isLight ? 'border-amber-300/30 bg-amber-50/30' : 'border-amber-500/20 bg-black/20'
      }`}>
        {/* Status indicator */}
        <div className="flex items-center gap-2 mb-3">
          <div className={`w-2 h-2 rounded-full ${
            isConnected ? 'bg-emerald-500' : 'bg-red-500'
          }`} />
          <span className={`text-[9px] font-cinzel tracking-wider ${
            isLight ? 'text-amber-600/60' : 'text-amber-500/50'
          }`}>
            {isConnected ? 'KODEKS AKTYWNY' : 'ROZŁĄCZONY'}
          </span>
          <span className={`text-[9px] ml-auto ${isLight ? 'text-amber-600/40' : 'text-amber-500/30'}`}>
            ᛊ ᛏ ᛒ
          </span>
        </div>

        {/* Input container */}
        <div className={`flex items-end gap-3 p-3 rounded border-2 transition-all duration-300 ${
          isLight
            ? 'bg-white/60 border-amber-400/40 focus-within:border-amber-500'
            : 'bg-black/30 border-amber-500/30 focus-within:border-amber-400'
        }`}>
          <Scroll className={`shrink-0 mb-2 ${isLight ? 'text-amber-600/50' : 'text-amber-500/40'}`} size={18} />

          <textarea
            ref={inputRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Wpisz polecenie dla HYDRY..."
            disabled={isLoading}
            rows={1}
            className={`flex-1 bg-transparent resize-none outline-none font-cinzel text-sm ${
              isLight ? 'text-amber-900 placeholder:text-amber-400/50' : 'text-amber-100 placeholder:text-amber-500/40'
            }`}
            style={{ maxHeight: '150px' }}
          />

          <button
            onClick={sendMessage}
            disabled={!input.trim() || isLoading}
            className={`shrink-0 p-2.5 rounded transition-all duration-300 ${
              input.trim() && !isLoading
                ? isLight
                  ? 'bg-gradient-to-b from-amber-400 to-amber-500 text-white hover:from-amber-500 hover:to-amber-600'
                  : 'bg-gradient-to-b from-amber-600 to-amber-700 text-amber-100 hover:from-amber-500 hover:to-amber-600'
                : isLight
                  ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                  : 'bg-slate-800 text-slate-600 cursor-not-allowed'
            }`}
            style={{}}
          >
            {isLoading ? (
              <Loader2 className="animate-spin" size={18} />
            ) : (
              <Send size={18} />
            )}
          </button>
        </div>

        {/* Hint */}
        <div className={`flex items-center justify-between mt-2 text-[8px] font-cinzel ${
          isLight ? 'text-amber-600/40' : 'text-amber-500/30'
        }`}>
          <span>Enter = wyślij • Shift+Enter = nowa linia</span>
          <span>◆ HYDRA 10.4 ◆</span>
        </div>
      </div>
    </div>
  );
};

// Message Bubble Component
const MessageBubble: React.FC<{ message: Message; isLight: boolean }> = ({ message, isLight }) => {
  const [expanded, setExpanded] = useState(true);
  const isUser = message.role === 'user';
  const isSystem = message.role === 'system';

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-[85%] rounded p-4 border transition-all duration-300 ${
          isUser
            ? isLight
              ? 'bg-amber-100/80 border-amber-300/50 text-amber-900'
              : 'bg-amber-900/30 border-amber-500/30 text-amber-100'
            : isSystem
              ? isLight
                ? 'bg-slate-100/80 border-slate-300/50 text-slate-700'
                : 'bg-slate-800/30 border-slate-600/30 text-slate-300'
              : isLight
                ? 'bg-white/80 border-amber-400/30 text-slate-800'
                : 'bg-black/40 border-amber-500/20 text-amber-50'
        }`}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            {isUser ? (
              <>
                <span className={`text-sm ${isLight ? 'text-amber-600' : 'text-amber-400'}`}>ᚹ</span>
                <span className={`text-[9px] font-cinzel font-semibold tracking-wider ${
                  isLight ? 'text-amber-700' : 'text-amber-400'
                }`}>
                  WIEDŹMIN
                </span>
              </>
            ) : isSystem ? (
              <>
                <span className={`text-sm ${isLight ? 'text-slate-500' : 'text-slate-400'}`}>ᛊ</span>
                <span className={`text-[9px] font-cinzel font-semibold tracking-wider ${
                  isLight ? 'text-slate-600' : 'text-slate-400'
                }`}>
                  SYSTEM
                </span>
              </>
            ) : (
              <>
                <Sparkles size={14} className={isLight ? 'text-amber-600' : 'text-amber-500'} />
                <span className={`text-[9px] font-cinzel font-semibold tracking-wider ${
                  isLight ? 'text-amber-700' : 'text-amber-500'
                }`}>
                  HYDRA
                </span>
              </>
            )}
          </div>

          <span className={`text-[8px] font-cinzel ${
            isLight ? 'text-slate-400' : 'text-slate-600'
          }`}>
            {message.timestamp.toLocaleTimeString('pl-PL', { hour: '2-digit', minute: '2-digit' })}
          </span>
        </div>

        {/* Content */}
        <div className={`text-sm font-cinzel leading-relaxed whitespace-pre-wrap ${
          !expanded && message.content.length > 500 ? 'line-clamp-5' : ''
        }`}>
          {message.content}
        </div>

        {/* Expand/Collapse for long messages */}
        {message.content.length > 500 && (
          <button
            onClick={() => setExpanded(!expanded)}
            className={`mt-2 flex items-center gap-1 text-[9px] font-cinzel ${
              isLight ? 'text-amber-600 hover:text-amber-700' : 'text-amber-500 hover:text-amber-400'
            }`}
          >
            {expanded ? (
              <>
                <ChevronUp size={12} />
                Zwiń
              </>
            ) : (
              <>
                <ChevronDown size={12} />
                Rozwiń
              </>
            )}
          </button>
        )}
      </div>
    </div>
  );
};

// Mock responses for browser development
function getMockResponse(input: string): string {
  const lower = input.toLowerCase();

  if (lower.includes('hello') || lower.includes('cześć') || lower.includes('witaj')) {
    return '⚔ Witaj, Wiedźminie! ⚔\n\nJestem HYDRA - Czterogłowa Bestia gotowa do służby.\n\nCo mogę dla Ciebie zrobić?\n\n• Analiza kodu (Serena)\n• Operacje systemowe (Desktop Commander)\n• Automatyzacja przeglądarki (Playwright)\n• Wieloagentowe zadania (Swarm)';
  }

  if (lower.includes('status') || lower.includes('health')) {
    return '📊 **STATUS SYSTEMU:**\n\n✅ Serena (port 9000) - Online\n✅ Desktop Commander (port 8100) - Online\n⚠️ Playwright (port 5200) - Offline\n✅ Ollama - 3 modele aktywne\n\n**Zasoby:**\n• CPU: 35%\n• RAM: 57% (9.1GB / 16GB)\n\nSystem gotowy do działania!';
  }

  if (lower.includes('pomoc') || lower.includes('help')) {
    return '📖 **KODEKS HYDRY - POMOC:**\n\n**Dostępne komendy:**\n• `/hydra` - Pełne instrukcje\n• `/ai <pytanie>` - Szybkie zapytanie AI (local)\n• `/swarm <zadanie>` - Agent Swarm (12 agentów)\n• `/yolo` - Przełącz tryb YOLO\n\n**Przykłady:**\n• "Przeanalizuj kod w src/"\n• "Otwórz stronę google.com"\n• "Znajdź wszystkie pliki .ts"';
  }

  return `🤔 Przetwarzam Twoje polecenie...\n\n**Otrzymano:** "${input}"\n\n*W trybie demonstracyjnym (przeglądarka). W pełnej wersji HYDRA połączy się z Claude CLI.*\n\n---\n\n💡 **Wskazówka:** Uruchom aplikację przez Tauri aby uzyskać pełną funkcjonalność.`;
}

export default ChatInterface;
