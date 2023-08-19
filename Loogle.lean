import Lean.Meta
import Mathlib.Tactic.Find
import Mathlib.Tactic.ToExpr
import Mathlib.Tactic.RunCmd
import Seccomp

open Lean Core Meta Elab Term Command

elab "compileTimeSearchPath" : term =>
  return toExpr (← searchPathRef.get)

unsafe def work (mod : String) (query : String) : IO Unit := do
  searchPathRef.set compileTimeSearchPath
  withImportModules [{module := mod.toName}, {module := `Mathlib.Tactic.Find}] {} 0 fun env => do
    IO.println "Loogle starting" -- need to write something before enabling seccomp
    Seccomp.enable
    let ctx := {fileName := "", fileMap := Inhabited.default}
    let state := {env}
    Prod.fst <$> (CoreM.toIO · ctx state) do
      match Parser.runParserCategory (← getEnv) `find_patterns query with
      | .error err => IO.println err
      | .ok s => do
        MetaM.run' do
          let args ← TermElabM.run' $ Mathlib.Tactic.Find.parseFindPatterns (.mk s)
          match ← Mathlib.Tactic.Find.find args with
          | .ok (header, names) => do
              IO.println (← header.toString)
              names.forM (fun name => IO.println name)
          | .error err => IO.println (← err.toString)

unsafe def main (args : List String) : IO Unit := do
   match args with
  | [query] => work "Mathlib" query
  | [mod, query] => work mod query
  | _ => IO.println "Usage: loogle [module] query"
