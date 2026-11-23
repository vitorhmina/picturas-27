"use client";

import { useEffect, useRef } from "react";
import { usePathname, useRouter } from "next/navigation";
import { useSession } from "@/providers/session-provider";
import { useGetSocket } from "@/lib/queries/projects";
import { fetchProcessStatus, fetchProject } from "@/lib/projects";
import { useToast } from "@/hooks/use-toast";
import { ToastAction } from "@/components/ui/toast";

// Tells the user when a project they started finishes or fails while they are
// somewhere else in the app (the project's own page shows its progress itself).
export function ProcessingNotifier() {
  const session = useSession();
  const socket = useGetSocket(session.token);
  const path = usePathname();
  const router = useRouter();
  const { toast } = useToast();
  const pathRef = useRef(path);
  pathRef.current = path;
  // runs already announced, as "<projectId>:<token>"
  const announced = useRef(new Set<string>());
  // one status check at a time per project; an event that arrives meanwhile
  // asks for one more check (it may be the run's last step)
  const checking = useRef(new Set<string>());
  const recheck = useRef(new Set<string>());

  useEffect(() => {
    const s = socket.data;
    if (!s) return;

    const onProjectPage = (projectId: string) =>
      pathRef.current === `/dashboard/${projectId}`;

    const projectName = async (projectId: string) => {
      try {
        const p = await fetchProject(session.user._id, projectId, session.token);
        return p.name;
      } catch {
        return "Your project";
      }
    };

    const open = (projectId: string, mode: "results" | "edit") => (
      <ToastAction
        altText="Open project"
        onClick={() => router.push(`/dashboard/${projectId}?mode=${mode}&view=grid`)}
      >
        Open
      </ToastAction>
    );

    async function onProcessUpdate(_msgId: string, meta?: { projectId?: string }) {
      const projectId = meta?.projectId;
      if (!projectId || onProjectPage(projectId)) return;
      if (checking.current.has(projectId)) {
        recheck.current.add(projectId);
        return;
      }
      checking.current.add(projectId);
      try {
        // the run's own project only (shared projects of other owners are not resolved here)
        const status = await fetchProcessStatus(session.user._id, projectId, session.token);
        const key = `${projectId}:${status.token}`;
        if (!status.committed || announced.current.has(key)) return;
        announced.current.add(key);
        toast({
          title: "Processing finished",
          description: `${await projectName(projectId)}: the results are ready.`,
          action: open(projectId, "results"),
        });
      } catch {
        // not this user's project, or the server is unavailable: nothing to announce
      } finally {
        checking.current.delete(projectId);
        if (recheck.current.delete(projectId)) onProcessUpdate(_msgId, meta);
      }
    }

    async function onProcessError(payload: { error_msg?: string; projectId?: string }) {
      const projectId = payload?.projectId;
      if (!projectId || onProjectPage(projectId)) return;
      toast({
        title: "Processing failed",
        description: `${await projectName(projectId)}: ${payload.error_msg || "the project could not be processed."}`,
        variant: "destructive",
        action: open(projectId, "edit"),
      });
    }

    s.on("process-update", onProcessUpdate);
    s.on("process-error", onProcessError);
    return () => {
      s.off("process-update", onProcessUpdate);
      s.off("process-error", onProcessError);
    };
  }, [socket.data, session.user._id, session.token, router, toast]);

  return null;
}
