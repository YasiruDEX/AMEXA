"""AMEXA entrypoint: POST /chat on port 8000, plus the lunch/tea scheduler in the background."""
import logging
import os
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

import uvicorn
import html
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel

import agent
import persona

log = logging.getLogger("break-bot")
_sessions: Dict[str, List[Any]] = {}
MAX_HISTORY = 20


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = "default"
    context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    response: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    sched = agent.schedule(background=True) if agent.WEBHOOK_URL else None
    if not sched:
        log.warning("GOOGLE_CHAT_WEBHOOK_URL not set; scheduler disabled")
    yield
    if sched:
        sched.shutdown(wait=False)


__version__ = (Path(__file__).with_name("VERSION").read_text().strip()
               if Path(__file__).with_name("VERSION").exists() else "dev")
app = FastAPI(title="AMEXA", version=__version__, lifespan=lifespan)


def schedule_summary() -> str:
    return (f"Lunch at {agent.LUNCH_TIMES}, tea at {agent.TEA_TIMES} "
            f"({agent.SCHEDULE_DAYS}, {agent.TIMEZONE}). Vibe: {agent.VIBE}.")


def chat_with_agent(message: str, session_id: str, context: Optional[Dict[str, Any]]) -> str:
    from langchain.agents import AgentExecutor, create_tool_calling_agent
    from langchain_core.messages import AIMessage, HumanMessage
    from langchain_core.prompts import ChatPromptTemplate
    from langchain_core.tools import tool
    from langchain_openai import ChatOpenAI

    @tool
    def get_schedule() -> str:
        """Get the configured lunch/tea times, days, timezone and vibe."""
        return schedule_summary()

    @tool
    def get_today_menu() -> str:
        """Get today's breakfast, lunch and tea items from the menu sheet."""
        return (f"Breakfast: {agent.get_today_menu('breakfast') or 'not set'}; "
                f"Lunch: {agent.get_today_menu('lunch') or 'not set'}; "
                f"Tea: {agent.get_today_menu('tea') or 'not set'}")

    @tool
    def trigger_break_message(kind: str) -> str:
        """Immediately generate and post a break message to the team. kind must be 'lunch' or 'tea'."""
        if kind not in ("lunch", "tea"):
            return "kind must be 'lunch' or 'tea'"
        agent.run_break(kind)
        return f"{kind} message posted"

    tools = [get_schedule, get_today_menu, trigger_break_message]
    prompt = ChatPromptTemplate.from_messages([
        ("system",
         "{character}\n"
         "You are the break-time bot for the '{team}' Google Chat group. Chat with the user in character "
         "(short, dry, helpful). You only handle food: today's menu (breakfast, juice, lunch, tea), "
         "the lunch/tea/juice schedule, and triggering lunch/tea messages when asked. Politely decline "
         "anything else (no custom messages, announcements, GitHub or repo questions).\n"
         "- Never use em dashes (—) or en dashes (–).\n"
         "- When asked about the menu, call get_today_menu and quote the items exactly as returned; never shorten or rename dishes.\n"
         "Extra context: {context}"),
        ("placeholder", "{history}"),
        ("human", "{input}"),
        ("placeholder", "{agent_scratchpad}"),
    ])
    llm = agent.make_llm()
    executor = AgentExecutor(agent=create_tool_calling_agent(llm, tools, prompt), tools=tools)
    history = _sessions.setdefault(session_id, [])
    out = executor.invoke({"input": message, "history": history, "team": agent.TEAM_NAME,
                           "character": persona.CHARACTER, "context": context or {}})["output"]
    history.extend([HumanMessage(message), AIMessage(out)])
    del history[:-MAX_HISTORY]
    return out


def chat_without_llm(message: str) -> str:
    """Keyword fallback when no OpenAI key is configured."""
    text = message.lower()
    for kind in ("lunch", "tea"):
        if kind in text and any(w in text for w in ("send", "trigger", "post", "now")):
            agent.run_break(kind)
            return f"Posted a {kind} message to the group ✅"
    return ("OPENAI_API_KEY isn't set, so I'm in basic mode. Try 'send lunch now', "
            "or 'send tea now'. " + schedule_summary())


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    try:
        if agent.OPENAI_API_KEY:
            reply = chat_with_agent(req.message, req.session_id or "default", req.context)
        else:
            reply = chat_without_llm(req.message)
    except Exception as e:
        log.exception("chat failed")
        reply = f"Sorry, something went wrong: {e}"
    return ChatResponse(response=reply)


@app.get("/ask", response_class=HTMLResponse)
def ask(q: str) -> HTMLResponse:
    """Morning-button target: answers 'what's for breakfast/lunch/tea, any juice?' from the sheet."""
    if not agent.is_question(q):
        raise HTTPException(status_code=400, detail="unknown question")
    answer = agent.ask(q).replace("*", "")
    note = "Posted in the group too." if agent.ASK_POST_TO_GROUP else ""
    return HTMLResponse(
        "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
        f"<title>{html.escape(persona.BOT_NAME)}</title>"
        "<body style='font-family:system-ui;display:grid;place-items:center;min-height:90vh;margin:0 16px'>"
        f"<div style='text-align:center'><h2 style='white-space:pre-line'>{html.escape(answer)}</h2><p style='color:#666'>{note}</p></div>")


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "version": __version__}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8000")))
