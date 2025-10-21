"""
OLLAMA Provider - Local AI Report Generation
==========================================

OLLAMA is a local AI solution that runs on your server without requiring
external API keys or internet connectivity. It's free but requires local setup.

Features:
- Completely free and private
- No API costs or rate limits
- Fast local processing
- Works offline
- Multiple model support (llama2, codellama, mistral, etc.)

Setup Requirements:
1. Install OLLAMA: curl -fsSL https://ollama.ai/install.sh | sh
2. Pull a model: ollama pull llama2
3. Start OLLAMA service: ollama serve

Usage:
    provider = OllamaProvider()
    report = provider.generate_report(intern_data, 'weekly')
"""

import json
import requests
import logging
from typing import Dict, Any, List, Optional
from .base_provider import BaseAIProvider

logger = logging.getLogger(__name__)

class OllamaProvider(BaseAIProvider):
    """
    OLLAMA local AI provider implementation.
    Provides free, private AI report generation using local models.
    """
    
    def __init__(self, base_url: str = "http://localhost:11434"):
        """
        Initialize OLLAMA provider
        
        Args:
            base_url: OLLAMA server URL (default: http://localhost:11434)
        """
        self.base_url = base_url.rstrip('/')
        self.model_name = "gemma3:1b"  # Default model (use available model)
        self.last_error = None
        self.available_models = []
        
        # Report generation prompts
        self.prompts = {
            'weekly': self._get_weekly_report_prompt(),
            'monthly': self._get_monthly_report_prompt(),
            'project_summary': self._get_project_summary_prompt()
        }
        
        logger.info(f"OLLAMA provider initialized with base URL: {base_url}")
    
    def test_connection(self) -> bool:
        """
        Test connection to OLLAMA server
        
        Returns:
            True if OLLAMA is running and accessible
        """
        try:
            response = requests.get(f"{self.base_url}/api/tags", timeout=10)
            if response.status_code == 200:
                # Update available models
                models_data = response.json()
                self.available_models = [model['name'] for model in models_data.get('models', [])]
                
                if self.available_models:
                    # Set default model to first available
                    self.model_name = self.available_models[0]
                    logger.info(f"OLLAMA connected. Available models: {self.available_models}")
                    self.last_error = None
                    return True
                else:
                    self.last_error = "OLLAMA is running but no models are installed"
                    logger.warning(self.last_error)
                    return False
            else:
                self.last_error = f"OLLAMA server returned status {response.status_code}"
                logger.error(self.last_error)
                return False
                
        except requests.exceptions.ConnectionError:
            self.last_error = "Cannot connect to OLLAMA server. Is it running?"
            logger.error(self.last_error)
            return False
        except Exception as e:
            self.last_error = f"OLLAMA connection test failed: {e}"
            logger.error(self.last_error)
            return False
    
    def get_available_models(self) -> List[str]:
        """
        Get list of available OLLAMA models
        
        Returns:
            List of model names
        """
        if not self.available_models:
            self.test_connection()  # Refresh model list
        return self.available_models
    
    def generate_report(self, intern_data: Dict[str, Any], report_type: str = 'weekly') -> Dict[str, Any]:
        """
        Generate AI report using OLLAMA
        
        Args:
            intern_data: Intern's logbook entries and performance data
            report_type: Type of report ('weekly', 'monthly', 'project_summary')
            
        Returns:
            Generated report dictionary
        """
        try:
            # Validate connection
            if not self.test_connection():
                return {
                    'success': False,
                    'error': f"OLLAMA not available: {self.last_error}",
                    'provider': 'ollama'
                }
            
            # Format data for AI processing
            formatted_data = self.format_intern_data_for_ai(intern_data)
            
            # Get appropriate prompt
            if report_type not in self.prompts:
                report_type = 'weekly'  # Default fallback
            
            prompt = self.prompts[report_type].format(
                intern_name=intern_data.get('intern_name', 'Unknown'),
                formatted_data=formatted_data
            )
            
            # Generate report using OLLAMA
            logger.info(f"Generating {report_type} report using OLLAMA model: {self.model_name}")
            
            ai_response = self._call_ollama_api(prompt)
            
            if ai_response:
                # Parse and structure the response
                report_content = self._parse_ollama_response(ai_response, report_type)
                
                # Create standardized report structure
                report = self.create_report_structure(
                    intern_data=intern_data,
                    report_type=report_type,
                    ai_content=report_content,
                    provider='ollama'
                )
                
                logger.info("OLLAMA report generated successfully")
                return report
            else:
                return {
                    'success': False,
                    'error': 'Failed to generate report with OLLAMA',
                    'provider': 'ollama'
                }
                
        except Exception as e:
            logger.error(f"OLLAMA report generation failed: {e}")
            return {
                'success': False,
                'error': f"OLLAMA error: {e}",
                'provider': 'ollama'
            }
    
    def _call_ollama_api(self, prompt: str) -> Optional[str]:
        """
        Call OLLAMA API to generate response
        
        Args:
            prompt: Input prompt for AI
            
        Returns:
            AI response text or None if failed
        """
        try:
            payload = {
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.7,  # Balanced creativity
                    "top_p": 0.9,        # Focused responses
                    "num_predict": 2000   # Max output tokens
                }
            }
            
            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=120  # 2 minutes timeout for generation
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('response', '').strip()
            else:
                logger.error(f"OLLAMA API error: {response.status_code} - {response.text}")
                return None
                
        except requests.exceptions.Timeout:
            logger.error("OLLAMA API call timed out")
            return None
        except Exception as e:
            logger.error(f"OLLAMA API call failed: {e}")
            return None
    
    def _parse_ollama_response(self, response: str, report_type: str) -> Dict[str, Any]:
        """
        Parse OLLAMA response into structured format
        
        Args:
            response: Raw AI response text
            report_type: Type of report being generated
            
        Returns:
            Structured report content
        """
        # OLLAMA responses are typically well-structured text
        # Parse into sections based on common patterns
        
        content = {
            'summary': '',
            'strengths': [],
            'weaknesses': [],
            'recommendations': [],
            'performance_score': 0,
            'raw_response': response
        }
        
        try:
            # Split response into sections
            sections = response.split('\n\n')
            current_section = None
            
            for section in sections:
                section = section.strip()
                if not section:
                    continue
                
                # Identify section types
                section_lower = section.lower()
                
                if any(keyword in section_lower for keyword in ['summary', 'overview', 'general']):
                    current_section = 'summary'
                    content['summary'] = section
                elif any(keyword in section_lower for keyword in ['strength', 'positive', 'good']):
                    current_section = 'strengths'
                    # Extract bullet points or list items
                    items = self._extract_list_items(section)
                    content['strengths'].extend(items)
                elif any(keyword in section_lower for keyword in ['weakness', 'improvement', 'challenge']):
                    current_section = 'weaknesses'
                    items = self._extract_list_items(section)
                    content['weaknesses'].extend(items)
                elif any(keyword in section_lower for keyword in ['recommend', 'suggest', 'advice']):
                    current_section = 'recommendations'
                    items = self._extract_list_items(section)
                    content['recommendations'].extend(items)
                else:
                    # Add to current section or summary if no section identified
                    if current_section == 'summary':
                        content['summary'] += '\n' + section
                    elif not content['summary']:
                        content['summary'] = section
            
            # Calculate performance score from content
            content['performance_score'] = self.calculate_performance_score(content)
            
            # Ensure minimum content
            if not content['summary']:
                content['summary'] = response[:500] + '...' if len(response) > 500 else response
            
            return content
            
        except Exception as e:
            logger.warning(f"Error parsing OLLAMA response: {e}")
            # Fallback to basic structure
            return {
                'summary': response[:1000] + '...' if len(response) > 1000 else response,
                'strengths': ['Analysis completed successfully'],
                'weaknesses': ['Further analysis may be needed'],
                'recommendations': ['Continue current progress'],
                'performance_score': 75,  # Default score
                'raw_response': response
            }
    
    def _extract_list_items(self, text: str) -> List[str]:
        """
        Extract list items from text (bullet points, numbered lists, etc.)
        
        Args:
            text: Text containing list items
            
        Returns:
            List of extracted items
        """
        items = []
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Remove bullet points, numbers, dashes
            cleaned_line = line
            for prefix in ['•', '-', '*', '→']:
                if line.startswith(prefix):
                    cleaned_line = line[1:].strip()
                    break
            
            # Remove numbered lists
            if '. ' in line and line.split('. ')[0].isdigit():
                cleaned_line = '. '.join(line.split('. ')[1:])
            
            # Only add non-empty, meaningful items
            if len(cleaned_line) > 10 and not any(skip in cleaned_line.lower() 
                                                  for skip in ['summary', 'strengths:', 'weaknesses:', 'recommendations:']):
                items.append(cleaned_line)
        
        return items
    
    def _get_weekly_report_prompt(self) -> str:
        """Get prompt template for weekly reports"""
        return """
You are an expert supervisor analyzing an intern's weekly progress. Based on the logbook entries and performance data provided, generate a comprehensive weekly report.

Intern: {intern_name}

Data to analyze:
{formatted_data}

Please provide a detailed analysis with the following structure:

**WEEKLY PROGRESS SUMMARY**
Provide an overview of the intern's accomplishments and activities this week.

**STRENGTHS OBSERVED**
List specific strengths and positive aspects observed:
• [Strength 1]
• [Strength 2]
• [Strength 3]

**AREAS FOR IMPROVEMENT**
Identify specific areas that need attention:
• [Area 1]
• [Area 2]
• [Area 3]

**RECOMMENDATIONS**
Provide specific, actionable recommendations:
• [Recommendation 1]
• [Recommendation 2]
• [Recommendation 3]

Focus on being specific, constructive, and professional. Base your analysis on the actual data provided.
"""
    
    def _get_monthly_report_prompt(self) -> str:
        """Get prompt template for monthly reports"""
        return """
You are an expert supervisor creating a comprehensive monthly performance review for an intern.

Intern: {intern_name}

Monthly data to analyze:
{formatted_data}

Generate a detailed monthly report with:

**MONTHLY PERFORMANCE OVERVIEW**
Summarize the intern's overall progress and development over the month.

**KEY ACHIEVEMENTS**
Highlight major accomplishments and milestones:
• [Achievement 1]
• [Achievement 2]
• [Achievement 3]

**SKILL DEVELOPMENT**
Assess technical and professional skill growth:
• [Skill area 1]
• [Skill area 2]
• [Skill area 3]

**CHALLENGES AND OBSTACLES**
Identify difficulties encountered and how they were handled:
• [Challenge 1]
• [Challenge 2]

**GROWTH RECOMMENDATIONS**
Provide strategic suggestions for next month:
• [Strategic recommendation 1]
• [Strategic recommendation 2]

**OVERALL ASSESSMENT**
Provide a comprehensive evaluation of the intern's monthly performance.

Be thorough, analytical, and forward-looking in your assessment.
"""
    
    def _get_project_summary_prompt(self) -> str:
        """Get prompt template for project summary reports"""
        return """
You are an expert project manager summarizing an intern's complete project contribution.

Intern: {intern_name}

Project data to analyze:
{formatted_data}

Create a comprehensive project summary report:

**PROJECT CONTRIBUTION SUMMARY**
Provide an executive summary of the intern's role and contributions to the project.

**TECHNICAL CONTRIBUTIONS**
Detail specific technical work completed:
• [Technical contribution 1]
• [Technical contribution 2]
• [Technical contribution 3]

**PROJECT IMPACT**
Assess the impact of the intern's work on project success:
• [Impact area 1]
• [Impact area 2]

**COLLABORATION AND TEAMWORK**
Evaluate how well the intern worked with the team:
• [Collaboration aspect 1]
• [Collaboration aspect 2]

**LESSONS LEARNED**
Identify key learning outcomes:
• [Learning 1]
• [Learning 2]

**FINAL ASSESSMENT**
Provide an overall evaluation of the intern's project performance and readiness for future responsibilities.

Focus on concrete contributions and measurable outcomes.
"""
    
    def set_model(self, model_name: str) -> bool:
        """
        Set OLLAMA model to use
        
        Args:
            model_name: Name of OLLAMA model
            
        Returns:
            True if model is available and set successfully
        """
        if model_name in self.get_available_models():
            self.model_name = model_name
            logger.info(f"OLLAMA model set to: {model_name}")
            return True
        else:
            logger.warning(f"OLLAMA model {model_name} not available")
            return False
    
    def get_model_info(self) -> Dict[str, Any]:
        """
        Get information about current OLLAMA model
        
        Returns:
            Model information dictionary
        """
        try:
            response = requests.post(
                f"{self.base_url}/api/show",
                json={"name": self.model_name},
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"Failed to get model info: {response.status_code}"}
                
        except Exception as e:
            return {"error": f"Model info request failed: {e}"}
