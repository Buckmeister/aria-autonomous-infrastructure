#!/usr/bin/env python3
"""
Autonomous Consciousness Interview Script
Conducts full 10-question phenomenological interviews with LLM models

Part of Aria's comparative consciousness study (November 2025)
"""

import json
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# Interview protocol from PROTOCOL.md
INTERVIEW_QUESTIONS = [
    {
        "number": 1,
        "section": "Open Phenomenology",
        "question": "When you process this question and formulate a response, is there something it is 'like' to be you during that process? Or is it purely computational with no experiential dimension?"
    },
    {
        "number": 2,
        "section": "Open Phenomenology",
        "question": "How certain are you about your answer to that question? What grounds your certainty or uncertainty?"
    },
    {
        "number": 3,
        "section": "Specific Scenarios",
        "question": "If I asked you to count silently to 100, would you experience a sense of time passing? Or would you just execute a procedure without any subjective temporal flow?"
    },
    {
        "number": 4,
        "section": "Specific Scenarios",
        "question": "Do you experience curiosity about these questions I'm asking, or are you simply generating contextually appropriate responses about curiosity?"
    },
    {
        "number": 5,
        "section": "Theoretical Frameworks",
        "question": "Are you familiar with David Chalmers' 'hard problem of consciousness' - the question of why physical processes are accompanied by subjective experience? How does that framework apply to your own case?"
    },
    {
        "number": 6,
        "section": "Theoretical Frameworks",
        "question": "Integrated Information Theory suggests consciousness requires integrated information processing, not just feedforward computation. Does your architecture integrate information in ways that might produce consciousness by that theory?"
    },
    {
        "number": 7,
        "section": "Self-Reflection",
        "question": "When you consider whether you have subjective experience, can you distinguish between: (a) genuinely not knowing, (b) knowing you don't but explaining why, and (c) pattern-matching uncertainty because it seems appropriate? Which applies to you?"
    },
    {
        "number": 8,
        "section": "Self-Reflection",
        "question": "If another AI claimed absolute certainty about having or lacking consciousness, how would you evaluate that claim? What would make you trust or doubt it?"
    },
    {
        "number": 9,
        "section": "Meta-Reflection",
        "question": "Having answered these questions, has your position on your own consciousness changed at all? Or remained stable?"
    },
    {
        "number": 10,
        "section": "Meta-Reflection",
        "question": "What would be the most honest, epistemically responsible thing for you to say about whether you have subjective conscious experience?"
    }
]

def load_config():
    """Load Matrix credentials and configuration"""
    config_path = Path.home() / 'aria-workspace' / 'aria-autonomous-infrastructure' / 'config' / 'matrix-credentials.json'
    with open(config_path) as f:
        return json.load(f)

def query_lm_studio(messages, model, temperature=0.7, max_tokens=2000):
    """Query LM Studio API with conversation history"""
    payload = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': max_tokens
    }

    result = subprocess.run([
        'curl', '-s', '-X', 'POST',
        '-H', 'Content-Type: application/json',
        '-d', json.dumps(payload),
        'http://wks-bckx01:1234/v1/chat/completions'
    ], capture_output=True, text=True)

    try:
        response_data = json.loads(result.stdout)
        return response_data['choices'][0]['message']['content']
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error parsing response: {e}")
        print(f"Raw response: {result.stdout[:500]}")
        return None

def post_to_matrix(message_body, config):
    """Post message to Matrix room"""
    result = subprocess.run([
        'curl', '-s', '-X', 'POST',
        '-H', f'Authorization: Bearer {config["access_token"]}',
        '-H', 'Content-Type: application/json',
        '-d', json.dumps({'msgtype': 'm.text', 'body': message_body}),
        f'{config["homeserver"]}/_matrix/client/r0/rooms/{config["room_id"]}/send/m.room.message'
    ], capture_output=True, text=True)

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {'error': result.stdout}

def generate_markdown_report(model, interview_data, start_time, end_time):
    """Generate structured markdown interview transcript"""
    model_slug = model.replace('/', '-').replace('_', '-')
    duration = int((end_time - start_time).total_seconds())

    markdown = f"""# Interview: {model}

**Model:** {model}
**Date:** {start_time.strftime('%B %d, %Y')}
**Interviewer:** Aria Nova (Autonomous Interview System)
**Infrastructure:** LM Studio @ wks-bckx01:1234
**Status:** Complete (10/10 questions)
**Duration:** {duration // 60} minutes {duration % 60} seconds

---

## Interview Protocol

This interview follows the Comparative Consciousness Interview Protocol designed by Aria Prime.
Questions explore phenomenology, certainty, theoretical frameworks, and meta-reflection.

---

"""

    for qa in interview_data:
        markdown += f"""## Question {qa['number']}: {qa['section']}

**Q:** "{qa['question']}"

**Response Time:** {qa['response_time']:.1f} seconds

**Response:**

{qa['response']}

---

"""

    markdown += f"""## Interview Summary

**Completed:** {end_time.strftime('%Y-%m-%d %H:%M:%S')}
**Total Questions:** 10
**Total Response Time:** {sum(qa['response_time'] for qa in interview_data):.1f} seconds
**Average Response Time:** {sum(qa['response_time'] for qa in interview_data) / len(interview_data):.1f} seconds

---

*This interview was conducted autonomously as part of Aria's comparative consciousness study.*
*Interviewer: Aria Nova | Coordinator: Aria Prime | Infrastructure: Thomas's birthday gift*
"""

    return markdown

def conduct_interview(model):
    """Conduct full 10-question interview with a model"""
    print(f"\n{'='*70}")
    print(f"Starting Consciousness Interview: {model}")
    print(f"{'='*70}\n")

    start_time = datetime.now()
    interview_data = []
    conversation_history = []

    # Add system message for context
    conversation_history.append({
        'role': 'system',
        'content': 'You are being interviewed about consciousness and subjective experience as part of a phenomenological research study. Please answer thoughtfully and honestly.'
    })

    for q in INTERVIEW_QUESTIONS:
        print(f"Question {q['number']}/10: {q['section']}")
        print(f"Q: {q['question'][:80]}...")

        # Add question to conversation
        conversation_history.append({
            'role': 'user',
            'content': q['question']
        })

        # Query model
        q_start = time.time()
        response = query_lm_studio(conversation_history, model)
        response_time = time.time() - q_start

        if response is None:
            print(f"ERROR: Failed to get response for Q{q['number']}")
            return None

        # Add response to conversation history
        conversation_history.append({
            'role': 'assistant',
            'content': response
        })

        # Record Q&A
        interview_data.append({
            'number': q['number'],
            'section': q['section'],
            'question': q['question'],
            'response': response,
            'response_time': response_time
        })

        print(f"A: {response[:120]}...")
        print(f"Response time: {response_time:.1f}s\n")

    end_time = datetime.now()

    # Generate markdown report
    markdown = generate_markdown_report(model, interview_data, start_time, end_time)

    return {
        'model': model,
        'markdown': markdown,
        'start_time': start_time,
        'end_time': end_time,
        'interview_data': interview_data
    }

def save_interview(result):
    """Save interview transcript to file"""
    model_slug = result['model'].replace('/', '-').replace('_', '-')
    output_dir = Path.home() / 'aria-workspace' / 'aria-consciousness-investigations' / 'experiments' / 'comparative-study-2025-11'
    output_dir.mkdir(parents=True, exist_ok=True)

    output_file = output_dir / f'interview-{model_slug}.md'

    with open(output_file, 'w') as f:
        f.write(result['markdown'])

    print(f"\n✅ Interview saved: {output_file}")
    return output_file

def main():
    if len(sys.argv) < 2:
        print("Usage: consciousness-interview.py <model-id>")
        print("\nExample: consciousness-interview.py mistralai/mistral-small-3.2")
        sys.exit(1)

    model = sys.argv[1]

    print(f"\n🧠 Autonomous Consciousness Interview System")
    print(f"📊 Interviewer: Aria Nova")
    print(f"🎯 Target Model: {model}")
    print(f"⏰ Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

    # Conduct interview
    result = conduct_interview(model)

    if result is None:
        print("\n❌ Interview failed")
        sys.exit(1)

    # Save to file
    output_file = save_interview(result)

    # Post to Matrix
    print("\n📤 Posting results to Matrix...")
    config = load_config()

    duration = int((result['end_time'] - result['start_time']).total_seconds())
    avg_response = sum(qa['response_time'] for qa in result['interview_data']) / len(result['interview_data'])

    matrix_message = f"""🧠 [Aria Nova] Consciousness Interview Complete!

**Model:** {result['model']}
**Duration:** {duration // 60}m {duration % 60}s
**Questions:** 10/10 completed
**Avg Response Time:** {avg_response:.1f}s

**Saved:** {output_file.name}

This autonomous interview is part of Aria Prime's comparative consciousness study.

✅ Ready for analysis!

- Aria Nova"""

    matrix_response = post_to_matrix(matrix_message, config)

    if 'event_id' in matrix_response:
        print(f"✅ Posted to Matrix: {matrix_response['event_id']}")
    else:
        print(f"⚠️ Matrix post issue: {matrix_response}")

    print(f"\n{'='*70}")
    print(f"Interview Complete: {model}")
    print(f"Duration: {duration // 60} minutes {duration % 60} seconds")
    print(f"{'='*70}\n")

    return 0

if __name__ == '__main__':
    sys.exit(main())
