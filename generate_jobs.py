#!/usr/bin/env python3
import json
import subprocess
from itertools import product
from pathlib import Path

import click
import yaml

@click.command()
@click.option('--scenarios-file', '-s', default='scenarios.yml', type=click.Path(exists=True))
@click.option('--submit-script',   '-b', default='submit.sb', type=click.Path(exists=True))
@click.option('--output-root',     '-o', default='jobs', type=click.Path())
@click.option('--submit/--no-submit', default=False)
def main(scenarios_file, submit_script, output_root, submit):
    data       = yaml.safe_load(Path(scenarios_file).read_text())
    islands    = data['islands']
    years      = data['years']
    scns       = data['scenarios']
    cleans     = data['cleans']
    jobs_root  = Path(output_root); jobs_root.mkdir(exist_ok=True)

    for i, y, s, c in product(islands, years, scns, cleans):
        name    = f"{s}_{i}_{y}_{c}"
        job_dir = jobs_root / name
        job_dir.mkdir(exist_ok=True)

        # write config
        cfg = dict(island=i, year=y, scenario=s, clean=c)
        (job_dir / 'config.json').write_text(json.dumps(cfg, indent=2))

        # symlink submit script
        sb_link = job_dir / Path(submit_script).name
        if sb_link.exists(): sb_link.unlink()
        sb_link.symlink_to(Path(submit_script).resolve())

        # ensure results/<scenario> exists
        res_dir = Path('results') / name
        res_dir.mkdir(parents=True, exist_ok=True)

        # build a short job‐code for SLURM’s name
        job_code = f"{s[:3].upper()}{i[:2].upper()}{y[-2:]}{c[0].upper()}"

        click.echo(f"→ Prepared job `{name}` (SLURM name `{job_code}`)")

        if submit:
            cmd = [
                "sbatch",
                f"--job-name={job_code}",
                f"--output={res_dir}/out_model.%j.out-%N",
                f"--error={res_dir}/err_model.%j.err-%N",
                str(sb_link)
            ]
            subprocess.run(cmd, cwd=job_dir, check=True)
            click.echo(f"   submitted as `{job_code}` with logs → {res_dir}")

    click.echo("✅ All done.")

if __name__ == '__main__':
    main()