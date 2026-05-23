import React, { useMemo, useState } from "react";

function Icon({ name, className = "" }) {
  const icons = {
    lock: "🔒",
    shield: "🛡️",
    search: "⌕",
    plus: "+",
    eye: "👁",
    eyeOff: "◌",
    card: "💳",
    note: "✎",
    key: "⌘",
    user: "◍",
    copy: "⧉",
    settings: "⚙",
    back: "‹",
    check: "✓",
    warning: "!",
    fileKey: "◆",
    finger: "◎",
    bold: "B",
    italic: "I",
    heading: "H",
    bullet: "•",
    checklist: "☑",
    quote: "❝"
  };

  return (
    <span aria-hidden="true" className={"inline-flex items-center justify-center leading-none " + className}>
      {icons[name] || "•"}
    </span>
  );
}

const guardians = [
  {
    id: "owl",
    icon: "🦉",
    name: "Owl",
    tagline: "Balanced everyday protection",
    detail: "Recommended for most vaults.",
    crypto: "Argon2id + XChaCha20-Poly1305",
    profile: "owl_v1"
  },
  {
    id: "lion",
    icon: "🦁",
    name: "Lion",
    tagline: "Maximum protection",
    detail: "For banking, identity, business, and high-value secrets.",
    crypto: "Argon2id high-memory + XChaCha20-Poly1305",
    profile: "lion_v1"
  },
  {
    id: "falcon",
    icon: "🦅",
    name: "Falcon",
    tagline: "Fast daily unlock",
    detail: "For lightweight vaults used many times daily.",
    crypto: "Argon2id balanced + XChaCha20-Poly1305",
    profile: "falcon_v1"
  }
];

const initialItems = [
  {
    id: 1,
    title: "Google Account",
    subtitle: "personal@gmail.com",
    category: "Login",
    icon: "key",
    updated: "Today",
    fields: [
      { label: "Username", masked: "personal@gmail.com", sensitive: false, value: "personal@gmail.com" },
      { label: "Password", masked: "••••••••••••", sensitive: true, value: "8hR9-q2Lx-44mK" },
      { label: "Website", masked: "accounts.google.com", sensitive: false, value: "accounts.google.com" }
    ]
  },
  {
    id: 2,
    title: "Primary Credit Card",
    subtitle: "Visa ending 4208",
    category: "Card",
    icon: "card",
    updated: "Yesterday",
    fields: [
      { label: "Card number", masked: "•••• •••• •••• 4208", sensitive: true, value: "4111 2934 7812 4208" },
      { label: "Expiry", masked: "••/••", sensitive: true, value: "08/29" },
      { label: "Name", masked: "A. User", sensitive: false, value: "A. User" }
    ]
  },
  {
    id: 3,
    title: "Passport Details",
    subtitle: "Identity document",
    category: "Identity",
    icon: "user",
    updated: "1 week ago",
    fields: [
      { label: "Document number", masked: "••••••••9081", sensitive: true, value: "P90819081" },
      { label: "Country", masked: "India", sensitive: false, value: "India" },
      { label: "Expiry", masked: "••••", sensitive: true, value: "2031" }
    ]
  }
];

const initialNotes = [
  {
    id: "note-1",
    type: "document",
    title: "Recovery Instructions",
    preview: "Keep printed recovery sheet in home safe.",
    body: "Keep printed recovery sheet in home safe. Do not store screenshots of the recovery phrase.",
    updated: "3 days ago",
    blocks: [
      { type: "heading", text: "Recovery Instructions" },
      { type: "paragraph", text: "Keep printed recovery sheet in home safe. Do not store screenshots of the recovery phrase." },
      { type: "check", text: "Print recovery sheet", checked: true },
      { type: "check", text: "Store one sealed copy with important documents", checked: false },
      { type: "quote", text: "If the master password and recovery phrase are both lost, the vault cannot be restored." }
    ]
  },
  {
    id: "note-2",
    type: "document",
    title: "Bank Support Notes",
    preview: "Branch relationship manager and support timing.",
    body: "Relationship manager: R. Mehta. Preferred support window: weekday mornings.",
    updated: "5 days ago",
    blocks: [
      { type: "heading", text: "Bank Support Notes" },
      { type: "paragraph", text: "Relationship manager: R. Mehta." },
      { type: "bullet", text: "Preferred support window: weekday mornings" },
      { type: "bullet", text: "Ask for card replacement desk if primary line is busy" }
    ]
  },
  {
    id: "note-3",
    type: "document",
    title: "Private Travel Checklist",
    preview: "Passport, backup card, insurance, emergency contact.",
    body: "Carry passport copy, backup card, insurance policy number, and emergency contact details.",
    updated: "1 week ago",
    blocks: [
      { type: "heading", text: "Private Travel Checklist" },
      { type: "check", text: "Passport copy", checked: true },
      { type: "check", text: "Backup card", checked: false },
      { type: "check", text: "Insurance policy number", checked: false },
      { type: "paragraph", text: "Keep encrypted vault backup before travel." }
    ]
  }
];

const navItems = [
  { id: "dashboard", label: "Vault", icon: "shield" },
  { id: "notes", label: "Notes", icon: "note" },
  { id: "categories", label: "Types", icon: "fileKey" },
  { id: "settings", label: "Settings", icon: "settings" }
];

const appRoutes = ["welcome", "setup", "recovery", "created", "unlock", "dashboard", "item", "notes", "noteDetail", "addNote", "add", "categories", "settings"];

function runPrototypeTests() {
  const failures = [];

  if (!guardians.some((guardian) => guardian.id === "owl")) failures.push("Owl guardian missing.");
  if (!guardians.every((guardian) => guardian.profile && guardian.crypto)) failures.push("Guardian crypto metadata missing.");
  if (!initialItems.every((item) => item.id && item.title && item.fields && item.fields.length)) failures.push("Vault item fixture invalid.");
  if (!initialItems.some((item) => item.fields.some((field) => field.sensitive === true))) failures.push("Sensitive field fixture missing.");
  if (!initialNotes.every((note) => note.id && note.title && note.body)) failures.push("Secure note fixture invalid.");
  if (!initialNotes.every((note) => note.type === "document" && Array.isArray(note.blocks) && note.blocks.length > 0)) failures.push("Rich document note fixture invalid.");
  if (!initialNotes.some((note) => note.blocks.some((block) => block.type === "check"))) failures.push("Checklist block fixture missing.");
  if (!initialNotes.some((note) => note.blocks.some((block) => block.type === "quote"))) failures.push("Quote block fixture missing.");
  if (!initialNotes.some((note) => note.blocks.some((block) => block.type === "bullet"))) failures.push("Bullet block fixture missing.");
  if (initialItems.filter((item) => item.title.toLowerCase().includes("google")).length !== 1) failures.push("Search fixture failed.");
  if (!navItems.some((item) => item.id === "notes")) failures.push("Notes nav missing.");
  if (!navItems.some((item) => item.id === "settings")) failures.push("Settings nav missing.");
  if (!appRoutes.includes("addNote") || !appRoutes.includes("noteDetail")) failures.push("Rich note routes missing.");
  if (!appRoutes.includes("item") || !appRoutes.includes("dashboard")) failures.push("Vault item routes missing.");

  if (failures.length > 0) {
    throw new Error("Prototype self-test failed: " + failures.join(" "));
  }

  return true;
}

runPrototypeTests();

function Shell({ children, dark = false }) {
  const outerClass = dark ? "min-h-screen bg-zinc-950 text-white" : "min-h-screen bg-zinc-50 text-zinc-950";
  const innerClass = dark
    ? "mx-auto min-h-screen w-full max-w-[430px] border-x border-zinc-900 bg-zinc-950 shadow-sm md:my-6 md:min-h-[860px] md:rounded-[2rem] md:border"
    : "mx-auto min-h-screen w-full max-w-[430px] border-x border-zinc-100 bg-white shadow-sm md:my-6 md:min-h-[860px] md:rounded-[2rem] md:border";

  return (
    <div className={outerClass}>
      <div className={innerClass}>{children}</div>
    </div>
  );
}

function PrimaryButton({ children, onClick, dark = false }) {
  const buttonClass = dark
    ? "h-14 w-full rounded-2xl bg-white text-base font-semibold text-zinc-950 active:scale-[0.99]"
    : "h-14 w-full rounded-2xl bg-zinc-950 text-base font-semibold text-white active:scale-[0.99]";

  return (
    <button type="button" onClick={onClick} className={buttonClass}>
      {children}
    </button>
  );
}

function Welcome({ onStart }) {
  return (
    <Shell>
      <main className="flex min-h-screen flex-col px-6 pb-6 pt-12 md:min-h-[860px]">
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-zinc-950 text-white">
          <Icon name="fileKey" className="text-xl" />
        </div>

        <div className="mt-16">
          <p className="text-sm font-medium text-zinc-500">Private vault</p>
          <h1 className="mt-3 text-5xl font-semibold leading-[0.95] tracking-tight text-zinc-950">Your digital life, locked in one file.</h1>
          <p className="mt-5 text-base leading-7 text-zinc-500">A portable encrypted vault for passwords, notes, cards, and identity details. You choose where it lives.</p>
        </div>

        <div className="mt-10 space-y-3 text-sm text-zinc-700">
          <div className="flex items-center gap-3"><Icon name="check" className="h-5 w-5 rounded-full bg-zinc-100 text-xs" /> Zero-knowledge</div>
          <div className="flex items-center gap-3"><Icon name="check" className="h-5 w-5 rounded-full bg-zinc-100 text-xs" /> Local-first</div>
          <div className="flex items-center gap-3"><Icon name="check" className="h-5 w-5 rounded-full bg-zinc-100 text-xs" /> Portable vault file</div>
        </div>

        <div className="mt-auto pt-10">
          <PrimaryButton onClick={onStart}>Create vault</PrimaryButton>
          <button type="button" className="mt-4 h-12 w-full rounded-2xl text-sm font-medium text-zinc-500">Open existing vault</button>
        </div>
      </main>
    </Shell>
  );
}

function Setup({ onNext }) {
  const [selected, setSelected] = useState("owl");
  const guardian = guardians.find((item) => item.id === selected) || guardians[0];

  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-8 md:min-h-[860px]">
        <header>
          <p className="text-sm font-medium text-zinc-500">Step 1 of 2</p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight">Choose Guardian</h1>
          <p className="mt-2 text-sm leading-6 text-zinc-500">A Guardian is a simple name for your vault protection profile.</p>
        </header>

        <section className="mt-7 space-y-3">
          {guardians.map((item) => {
            const isSelected = selected === item.id;
            const cardClass = isSelected ? "border-zinc-950 bg-zinc-950 text-white" : "border-zinc-200 bg-white";
            const descriptionClass = isSelected ? "text-zinc-300" : "text-zinc-500";
            const iconClass = isSelected ? "bg-white/10" : "bg-zinc-100";

            return (
              <button key={item.id} type="button" onClick={() => setSelected(item.id)} className={"w-full rounded-3xl border p-4 text-left transition " + cardClass}>
                <div className="flex items-center gap-4">
                  <div className={"flex h-12 w-12 items-center justify-center rounded-2xl text-2xl " + iconClass}>{item.icon}</div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-3">
                      <p className="font-semibold">{item.name}</p>
                      {isSelected ? <Icon name="check" className="h-5 w-5 rounded-full border border-white/30 text-xs" /> : null}
                    </div>
                    <p className={"mt-1 text-sm " + descriptionClass}>{item.tagline}</p>
                  </div>
                </div>
              </button>
            );
          })}
        </section>

        <section className="mt-6 rounded-3xl bg-zinc-100 p-4">
          <div className="flex items-center gap-3">
            <span className="text-3xl">{guardian.icon}</span>
            <div>
              <p className="font-semibold">{guardian.name} details</p>
              <p className="text-sm text-zinc-500">{guardian.detail}</p>
            </div>
          </div>
          <div className="mt-4 rounded-2xl bg-white p-3 text-xs leading-5 text-zinc-500">
            <p>{guardian.crypto}</p>
            <p>Profile: {guardian.profile}</p>
          </div>
        </section>

        <section className="mt-6 space-y-3">
          <input type="password" placeholder="Master password" className="h-14 w-full rounded-2xl border border-zinc-200 bg-white px-4 text-base outline-none focus:border-zinc-400" />
          <input type="password" placeholder="Confirm password" className="h-14 w-full rounded-2xl border border-zinc-200 bg-white px-4 text-base outline-none focus:border-zinc-400" />
          <div className="rounded-2xl bg-amber-50 p-4 text-sm leading-6 text-amber-800"><Icon name="warning" className="mr-2 inline-flex h-5 w-5 rounded-full border border-amber-700 text-xs" />No password means no recovery unless you save a recovery phrase.</div>
        </section>

        <div className="mt-7"><PrimaryButton onClick={onNext}>Create encrypted vault</PrimaryButton></div>
      </main>
    </Shell>
  );
}

function RecoverySetup({ onContinue }) {
  const recoveryWords = ["orbit", "stone", "river", "falcon", "ember", "north", "echo", "silent", "forest", "velvet", "copper", "night"];

  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-8 md:min-h-[860px]">
        <p className="text-sm font-medium text-zinc-500">Step 2 of 2</p>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight">Recovery phrase</h1>
        <p className="mt-3 text-sm leading-6 text-zinc-500">Save this phrase offline. It helps recover your vault if your device is lost.</p>

        <div className="mt-8 rounded-3xl bg-zinc-950 p-6 text-white">
          <div className="grid grid-cols-2 gap-3 text-sm">
            {recoveryWords.map((word, index) => (
              <div key={word} className="rounded-2xl bg-white/10 px-3 py-3"><span className="text-zinc-400">{index + 1}.</span> {word}</div>
            ))}
          </div>
        </div>

        <div className="mt-6 rounded-3xl bg-zinc-100 p-4 text-sm leading-6 text-zinc-600">Write this down on paper and keep it somewhere safe. Never store it in screenshots or chats.</div>

        <div className="mt-8 space-y-3">
          <PrimaryButton onClick={onContinue}>I saved my recovery phrase</PrimaryButton>
          <button type="button" className="h-12 w-full rounded-2xl text-sm font-medium text-zinc-500">Print recovery sheet</button>
        </div>
      </main>
    </Shell>
  );
}

function VaultCreated({ onContinue }) {
  return (
    <Shell>
      <main className="flex min-h-screen flex-col items-center justify-center px-6 text-center md:min-h-[860px]">
        <div className="flex h-24 w-24 items-center justify-center rounded-[2rem] bg-zinc-950 text-4xl text-white"><Icon name="check" className="text-4xl" /></div>
        <h1 className="mt-8 text-4xl font-semibold tracking-tight text-zinc-950">Vault created</h1>
        <p className="mt-4 max-w-sm text-base leading-7 text-zinc-500">Your encrypted vault file is ready. Only your master password can unlock it.</p>
        <div className="mt-10 w-full space-y-3">
          <PrimaryButton onClick={onContinue}>Open vault</PrimaryButton>
          <button type="button" className="h-12 w-full rounded-2xl text-sm font-medium text-zinc-500">Choose vault location</button>
        </div>
      </main>
    </Shell>
  );
}

function Unlock({ onOpen }) {
  return (
    <Shell dark>
      <main className="flex min-h-screen flex-col bg-zinc-950 px-6 pb-6 pt-14 text-white md:min-h-[860px] md:rounded-[2rem]">
        <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-[1.75rem] bg-white/10 text-3xl">🦉</div>
        <div className="mt-10 text-center">
          <h1 className="text-3xl font-semibold tracking-tight">Unlock vault</h1>
          <p className="mt-2 text-sm text-zinc-400">Protected by Owl Guardian</p>
        </div>
        <div className="mt-10 space-y-3">
          <input type="password" placeholder="Master password" className="h-14 w-full rounded-2xl border border-white/10 bg-white/10 px-4 text-base text-white outline-none placeholder:text-zinc-500 focus:border-white/30" />
          <PrimaryButton onClick={onOpen} dark>Unlock</PrimaryButton>
          <button type="button" onClick={onOpen} className="flex h-14 w-full items-center justify-center gap-2 rounded-2xl border border-white/10 text-sm font-semibold text-zinc-300"><Icon name="finger" className="text-lg" /> Use biometrics</button>
        </div>
        <p className="mt-auto text-center text-xs leading-5 text-zinc-500">Vault locks automatically when the app goes to background.</p>
      </main>
    </Shell>
  );
}

function Dashboard({ onSelect, onAdd, onSettings }) {
  const [query, setQuery] = useState("");
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return initialItems;
    return initialItems.filter((item) => (item.title + " " + item.subtitle + " " + item.category).toLowerCase().includes(q));
  }, [query]);

  return (
    <Shell>
      <main className="relative min-h-screen pb-28 md:min-h-[860px]">
        <header className="sticky top-0 z-10 border-b border-zinc-100 bg-white/95 px-5 pb-4 pt-7 backdrop-blur">
          <div className="flex items-center justify-between">
            <div><p className="text-sm text-zinc-500">Owl Guardian</p><h1 className="text-3xl font-semibold tracking-tight">Vault</h1></div>
            <button type="button" onClick={onSettings} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-100"><Icon name="settings" /></button>
          </div>
          <div className="relative mt-5"><Icon name="search" className="absolute left-4 top-3.5 text-zinc-400" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search" className="h-12 w-full rounded-2xl border-0 bg-zinc-100 pl-11 pr-4 outline-none" /></div>
        </header>

        <section className="px-5 pt-5">
          <div className="rounded-3xl bg-zinc-950 p-5 text-white">
            <div className="flex items-center justify-between"><div><p className="text-sm text-zinc-400">Vault health</p><p className="mt-1 text-xl font-semibold">Good</p></div><Icon name="shield" className="text-2xl" /></div>
            <p className="mt-4 text-sm leading-6 text-zinc-400">Recovery sheet not printed. Add it before storing critical secrets.</p>
          </div>
        </section>

        <section className="px-5 pt-6">
          <div className="mb-3 flex items-center justify-between"><h2 className="text-lg font-semibold">Items</h2><span className="text-sm text-zinc-400">{filtered.length}</span></div>
          <div className="space-y-2">
            {filtered.map((item) => (
              <button key={item.id} type="button" onClick={() => onSelect(item)} className="flex w-full items-center gap-3 rounded-3xl bg-white p-4 text-left shadow-[0_1px_0_rgba(0,0,0,0.06)] active:scale-[0.99]">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-zinc-100 text-lg"><Icon name={item.icon} /></div>
                <div className="min-w-0 flex-1"><p className="truncate font-semibold text-zinc-950">{item.title}</p><p className="mt-1 truncate text-sm text-zinc-500">{item.subtitle}</p></div>
                <span className="text-xs text-zinc-400">{item.updated}</span>
              </button>
            ))}
          </div>
        </section>

        <button type="button" onClick={onAdd} className="fixed bottom-24 left-1/2 z-30 flex h-14 w-14 -translate-x-1/2 items-center justify-center rounded-full bg-zinc-950 text-2xl font-semibold text-white shadow-xl"><Icon name="plus" className="text-2xl" /></button>
      </main>
    </Shell>
  );
}

function ItemDetail({ item, onBack }) {
  const [hiddenFields, setHiddenFields] = useState({});
  const isFieldHidden = (label) => hiddenFields[label] !== false;
  const toggleField = (label) => setHiddenFields((current) => ({ ...current, [label]: !isFieldHidden(label) }));

  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-6 md:min-h-[860px]">
        <header className="flex items-center justify-between"><button type="button" onClick={onBack} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-100 text-2xl"><Icon name="back" /></button><button type="button" className="rounded-full bg-zinc-100 px-4 py-3 text-sm font-semibold">Edit</button></header>
        <section className="mt-8"><div className="flex h-16 w-16 items-center justify-center rounded-3xl bg-zinc-100 text-2xl"><Icon name={item.icon} /></div><h1 className="mt-5 text-3xl font-semibold tracking-tight">{item.title}</h1><p className="mt-2 text-sm text-zinc-500">{item.category} · Updated {item.updated}</p></section>
        <section className="mt-8 space-y-3">
          {item.fields.map((field) => {
            const fieldHidden = field.sensitive ? isFieldHidden(field.label) : false;
            const displayValue = field.sensitive && fieldHidden ? field.masked : field.value;
            return (
              <div key={field.label} className="rounded-3xl bg-zinc-100 p-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-zinc-400">{field.label}</p>
                <div className="mt-3 flex items-center justify-between gap-4">
                  <p className="break-all text-base font-semibold text-zinc-950">{displayValue}</p>
                  <div className="flex items-center gap-2">
                    {field.sensitive ? <button type="button" onClick={() => toggleField(field.label)} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white text-zinc-500" aria-label={(fieldHidden ? "View " : "Hide ") + field.label}><Icon name={fieldHidden ? "eye" : "eyeOff"} /></button> : null}
                    <button type="button" className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white text-zinc-500" aria-label={"Copy " + field.label}><Icon name="copy" /></button>
                  </div>
                </div>
              </div>
            );
          })}
        </section>
        <div className="mt-6 rounded-3xl bg-zinc-950 p-4 text-sm leading-6 text-zinc-300">Clipboard clears automatically after 30 seconds.</div>
      </main>
    </Shell>
  );
}

function NotesPage({ onSelectNote, onAddNote }) {
  const [query, setQuery] = useState("");
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return initialNotes;
    return initialNotes.filter((note) => (note.title + " " + note.preview + " " + note.body).toLowerCase().includes(q));
  }, [query]);

  return (
    <Shell>
      <main className="min-h-screen pb-28 md:min-h-[860px]">
        <header className="sticky top-0 z-10 border-b border-zinc-100 bg-white/95 px-5 pb-4 pt-7 backdrop-blur">
          <div className="flex items-center justify-between"><div><p className="text-sm text-zinc-500">Encrypted writing</p><h1 className="text-3xl font-semibold tracking-tight">Notes</h1></div><button type="button" onClick={onAddNote} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-950 text-xl text-white"><Icon name="plus" /></button></div>
          <div className="relative mt-5"><Icon name="search" className="absolute left-4 top-3.5 text-zinc-400" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search notes" className="h-12 w-full rounded-2xl border-0 bg-zinc-100 pl-11 pr-4 outline-none" /></div>
        </header>
        <section className="px-5 pt-5"><div className="rounded-3xl bg-zinc-100 p-4 text-sm leading-6 text-zinc-600">Notes are stored inside the same encrypted vault file. They are private by default and never synced as readable text.</div></section>
        <section className="space-y-3 px-5 pt-5">
          {filtered.map((note) => (
            <button key={note.id} type="button" onClick={() => onSelectNote(note)} className="w-full rounded-3xl bg-white p-5 text-left shadow-[0_1px_0_rgba(0,0,0,0.06)] active:scale-[0.99]">
              <div className="flex items-start justify-between gap-3"><div className="min-w-0 flex-1"><p className="truncate text-lg font-semibold text-zinc-950">{note.title}</p><p className="mt-2 text-sm leading-6 text-zinc-500">{note.preview}</p></div><div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-zinc-100"><Icon name="note" /></div></div>
              <p className="mt-4 text-xs text-zinc-400">Updated {note.updated}</p>
            </button>
          ))}
        </section>
      </main>
    </Shell>
  );
}

function RichBlock({ block }) {
  if (block.type === "heading") return <h2 className="text-2xl font-semibold tracking-tight text-zinc-950">{block.text}</h2>;
  if (block.type === "bullet") return <div className="flex gap-3 text-base leading-7 text-zinc-800"><span className="mt-1 text-zinc-400">•</span><p>{block.text}</p></div>;
  if (block.type === "check") {
    const checkClass = block.checked ? "border-zinc-950 bg-zinc-950 text-white" : "border-zinc-300 text-transparent";
    const textClass = block.checked ? "text-zinc-500 line-through" : "text-zinc-800";
    return <div className="flex gap-3 text-base leading-7 text-zinc-800"><span className={"mt-1 flex h-5 w-5 shrink-0 items-center justify-center rounded-md border text-xs " + checkClass}>✓</span><p className={textClass}>{block.text}</p></div>;
  }
  if (block.type === "quote") return <blockquote className="border-l-4 border-zinc-300 pl-4 text-base italic leading-7 text-zinc-600">{block.text}</blockquote>;
  return <p className="text-base leading-8 text-zinc-800">{block.text}</p>;
}

function NoteDetail({ note, onBack }) {
  const blocks = Array.isArray(note.blocks) && note.blocks.length > 0 ? note.blocks : [{ type: "paragraph", text: note.body }];
  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-6 md:min-h-[860px]">
        <header className="flex items-center justify-between"><button type="button" onClick={onBack} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-100 text-2xl"><Icon name="back" /></button><button type="button" className="rounded-full bg-zinc-100 px-4 py-3 text-sm font-semibold">Edit</button></header>
        <section className="mt-8"><div className="flex h-16 w-16 items-center justify-center rounded-3xl bg-zinc-100 text-2xl"><Icon name="note" /></div><h1 className="mt-5 text-3xl font-semibold tracking-tight">{note.title}</h1><p className="mt-2 text-sm text-zinc-500">Rich Secure Document · Updated {note.updated}</p></section>
        <article className="mt-8 space-y-5 rounded-3xl bg-zinc-100 p-5">{blocks.map((block, index) => <RichBlock key={block.type + "-" + index} block={block} />)}</article>
        <div className="mt-6 rounded-3xl bg-zinc-950 p-4 text-sm leading-6 text-zinc-300">Rich text blocks are encrypted inside the vault payload. Search indexes are rebuilt only after unlock.</div>
      </main>
    </Shell>
  );
}

function RichTextToolbar() {
  const tools = [
    { icon: "heading", label: "Heading" },
    { icon: "bold", label: "Bold" },
    { icon: "italic", label: "Italic" },
    { icon: "bullet", label: "List" },
    { icon: "checklist", label: "Check" },
    { icon: "quote", label: "Quote" }
  ];
  return <div className="flex gap-2 overflow-x-auto rounded-2xl bg-zinc-100 p-2">{tools.map((tool) => <button key={tool.label} type="button" className="flex h-10 shrink-0 items-center gap-2 rounded-xl bg-white px-3 text-sm font-semibold text-zinc-700"><Icon name={tool.icon} className={tool.icon === "bold" ? "font-black" : tool.icon === "italic" ? "italic" : ""} />{tool.label}</button>)}</div>;
}

function AddNote({ onBack }) {
  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-6 md:min-h-[860px]">
        <header className="flex items-center justify-between"><button type="button" onClick={onBack} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-100 text-2xl"><Icon name="back" /></button><button type="button" className="text-sm font-semibold text-zinc-950">Save</button></header>
        <section className="mt-8 space-y-4">
          <input type="text" placeholder="Document title" className="h-14 w-full rounded-2xl border border-zinc-200 px-4 text-lg font-semibold outline-none" />
          <RichTextToolbar />
          <div className="min-h-[440px] rounded-3xl border border-zinc-200 bg-white p-5"><p className="text-2xl font-semibold tracking-tight text-zinc-400">Heading</p><p className="mt-5 text-base leading-8 text-zinc-400">Start writing a private document...</p><div className="mt-6 flex gap-3 text-zinc-400"><span className="mt-1">•</span><p className="leading-7">Add bullet points</p></div><div className="mt-3 flex gap-3 text-zinc-400"><span className="mt-1 flex h-5 w-5 items-center justify-center rounded-md border border-zinc-300 text-xs"> </span><p className="leading-7">Add checklist items</p></div></div>
        </section>
        <div className="mt-4 rounded-3xl bg-zinc-100 p-4 text-sm leading-6 text-zinc-600">Rich documents support headings, bold text, lists, checklists, quotes, and plain paragraphs. The saved document is encrypted as structured blocks inside the vault.</div>
      </main>
    </Shell>
  );
}

function Categories() {
  const categories = [
    { name: "Login", count: 12, icon: "key" },
    { name: "Cards", count: 4, icon: "card" },
    { name: "Secure Notes", count: initialNotes.length, icon: "note" },
    { name: "Identity", count: 2, icon: "user" }
  ];
  return (
    <Shell>
      <main className="min-h-screen px-5 pb-28 pt-7 md:min-h-[860px]">
        <header><p className="text-sm text-zinc-500">Vault organization</p><h1 className="text-3xl font-semibold tracking-tight">Types</h1></header>
        <section className="mt-8 space-y-3">{categories.map((category) => <button key={category.name} type="button" className="flex w-full items-center gap-4 rounded-3xl bg-white p-5 text-left shadow-[0_1px_0_rgba(0,0,0,0.06)]"><div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-zinc-100 text-xl"><Icon name={category.icon} /></div><div className="flex-1"><p className="font-semibold text-zinc-950">{category.name}</p><p className="mt-1 text-sm text-zinc-500">{category.count} items</p></div><Icon name="back" className="rotate-180 text-zinc-300" /></button>)}</section>
      </main>
    </Shell>
  );
}

function AddItem({ onBack, onAddNote }) {
  const [type, setType] = useState("Login");
  const types = [{ name: "Login", icon: "key" }, { name: "Card", icon: "card" }, { name: "Secure Note", icon: "note" }, { name: "Identity", icon: "user" }];
  return (
    <Shell>
      <main className="min-h-screen px-5 pb-6 pt-6 md:min-h-[860px]">
        <header className="flex items-center justify-between"><button type="button" onClick={onBack} className="flex h-11 w-11 items-center justify-center rounded-full bg-zinc-100 text-2xl"><Icon name="back" /></button><button type="button" className="text-sm font-semibold text-zinc-500">Save</button></header>
        <h1 className="mt-8 text-3xl font-semibold tracking-tight">Add item</h1>
        <section className="mt-8 space-y-4">
          <div><label className="mb-2 block text-sm font-medium text-zinc-500">Type</label><div className="grid grid-cols-2 gap-3">{types.map((itemType) => { const selected = type === itemType.name; const typeClass = selected ? "border-zinc-950 bg-zinc-950 text-white" : "border-zinc-200 bg-white"; const iconClass = selected ? "bg-white/10" : "bg-zinc-100"; return <button key={itemType.name} type="button" onClick={() => { setType(itemType.name); if (itemType.name === "Secure Note") onAddNote(); }} className={"rounded-3xl border p-4 text-left " + typeClass}><div className={"flex h-12 w-12 items-center justify-center rounded-2xl text-xl " + iconClass}><Icon name={itemType.icon} /></div><p className="mt-4 font-semibold">{itemType.name}</p></button>; })}</div></div>
          <input type="text" placeholder="Title" className="h-14 w-full rounded-2xl border border-zinc-200 px-4 outline-none" />
          <input type="text" placeholder="Username or email" className="h-14 w-full rounded-2xl border border-zinc-200 px-4 outline-none" />
          <input type="password" placeholder="Password" className="h-14 w-full rounded-2xl border border-zinc-200 px-4 outline-none" />
          <textarea placeholder="Notes" className="min-h-[140px] w-full rounded-2xl border border-zinc-200 p-4 outline-none" />
        </section>
      </main>
    </Shell>
  );
}

function SettingsPage() {
  const sections = ["Security", "Vault Backup", "Biometric Unlock", "Recovery Phrase", "Auto Lock", "Export Vault", "Danger Zone"];
  return (
    <Shell>
      <main className="min-h-screen px-5 pb-28 pt-7 md:min-h-[860px]">
        <header><p className="text-sm text-zinc-500">Vault preferences</p><h1 className="text-3xl font-semibold tracking-tight">Settings</h1></header>
        <section className="mt-8 space-y-2">{sections.map((section) => <button key={section} type="button" className="flex w-full items-center justify-between rounded-3xl bg-white px-5 py-5 text-left shadow-[0_1px_0_rgba(0,0,0,0.06)]"><span className="font-medium text-zinc-950">{section}</span><Icon name="back" className="rotate-180 text-zinc-300" /></button>)}</section>
      </main>
    </Shell>
  );
}

function BottomNav({ current, onChange }) {
  return (
    <div className="fixed bottom-0 left-1/2 z-20 flex w-full max-w-[430px] -translate-x-1/2 border-t border-zinc-100 bg-white px-3 pb-6 pt-3 md:bottom-6 md:rounded-b-[2rem]">
      {navItems.map((item) => {
        const active = current === item.id;
        const itemClass = active ? "text-zinc-950" : "text-zinc-400";
        return <button key={item.id} type="button" onClick={() => onChange(item.id)} className={"flex flex-1 flex-col items-center gap-1 rounded-2xl py-2 text-xs font-medium " + itemClass}><Icon name={item.icon} className="text-lg" />{item.label}</button>;
      })}
    </div>
  );
}

function MainApp({ screen, setScreen, setSelectedItem }) {
  if (screen === "notes") {
    return <div><NotesPage onAddNote={() => setScreen("addNote")} onSelectNote={(note) => { setSelectedItem(note); setScreen("noteDetail"); }} /><BottomNav current="notes" onChange={setScreen} /></div>;
  }
  if (screen === "categories") {
    return <div><Categories /><BottomNav current="categories" onChange={setScreen} /></div>;
  }
  if (screen === "settings") {
    return <div><SettingsPage /><BottomNav current="settings" onChange={setScreen} /></div>;
  }
  return <div><Dashboard onAdd={() => setScreen("add")} onSettings={() => setScreen("settings")} onSelect={(item) => { setSelectedItem(item); setScreen("item"); }} /><BottomNav current="dashboard" onChange={setScreen} /></div>;
}

export default function VaultGuardiansPrototype() {
  const [screen, setScreen] = useState("welcome");
  const [selectedItem, setSelectedItem] = useState(null);

  if (screen === "welcome") return <Welcome onStart={() => setScreen("setup")} />;
  if (screen === "setup") return <Setup onNext={() => setScreen("recovery")} />;
  if (screen === "recovery") return <RecoverySetup onContinue={() => setScreen("created")} />;
  if (screen === "created") return <VaultCreated onContinue={() => setScreen("unlock")} />;
  if (screen === "unlock") return <Unlock onOpen={() => setScreen("dashboard")} />;
  if (screen === "item" && selectedItem) return <ItemDetail item={selectedItem} onBack={() => setScreen("dashboard")} />;
  if (screen === "noteDetail" && selectedItem) return <NoteDetail note={selectedItem} onBack={() => setScreen("notes")} />;
  if (screen === "addNote") return <AddNote onBack={() => setScreen("notes")} />;
  if (screen === "add") return <AddItem onBack={() => setScreen("dashboard")} onAddNote={() => setScreen("addNote")} />;

  return <MainApp screen={screen} setScreen={setScreen} setSelectedItem={setSelectedItem} />;
}
