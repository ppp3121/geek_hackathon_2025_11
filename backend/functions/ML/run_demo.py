import traceback
try:
    from ML.synonym_normalizer import demo
    demo()
except Exception:
    traceback.print_exc()

