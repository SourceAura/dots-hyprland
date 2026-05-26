"""
wisteria.py — SiM Vector Memory (ChromaDB)
Semantic recall and persistent memory for the SiM Syndicate.
"""

import uuid
import os
from datetime import datetime, timezone


class WisteriaArchive:
    def __init__(self):
        from config import WISTERIA_PATH
        os.makedirs(str(WISTERIA_PATH), exist_ok=True)
        import chromadb
        self.client     = chromadb.PersistentClient(path=str(WISTERIA_PATH))
        self.collection = self.client.get_or_create_collection(name="sim_memory")

    def embed(self, text: str, source: str, tags: list = None) -> str:
        if not text.strip():
            return ""
        mem_id = f"mem-{uuid.uuid4().hex[:12]}"
        self.collection.add(
            documents=[text],
            metadatas=[{
                "source":    source,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "tags":      ",".join(tags or ["system"]),
            }],
            ids=[mem_id],
        )
        return mem_id

    def recall(self, query: str, n: int = 5) -> list[dict]:
        if self.collection.count() == 0:
            return []
        results = self.collection.query(
            query_texts=[query],
            n_results=min(n, self.collection.count()),
        )
        out = []
        if results["documents"] and results["documents"][0]:
            for i, doc in enumerate(results["documents"][0]):
                out.append({
                    "id":       results["ids"][0][i],
                    "document": doc,
                    "metadata": results["metadatas"][0][i],
                    "distance": results["distances"][0][i] if results.get("distances") else 0.0,
                })
        return out


wisteria = WisteriaArchive()
